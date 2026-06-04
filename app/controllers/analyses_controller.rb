# PVAR compute layer: create a run (response = GDP per capita by default, overridable per  B; predictor = user choice)
# and poll its status as JSON for the 2s front-end polling. The show action is HOT - it reads the
# slim scalar columns via .select and only loads the typed result tables once the run is completed.
class AnalysesController < ApplicationController
  WRITE_RATE_LIMIT  = 20   # create/destroy ops per IP per window - abuse/DoS mitigation (harden 2026-06-25)
  WRITE_RATE_WINDOW = 60    # seconds
  # Dedicated per-process throttle store: works in every env (test's Rails.cache is null_store); on multi-worker
  # prod the cap is per-worker, which still bounds a flood. Swap to a shared Redis store for a hard global cap.
  THROTTLE_STORE = ActiveSupport::Cache::MemoryStore.new(size: 2.megabytes)
  before_action :throttle_writes, only: %i[create destroy]

  # Run history (sidebar): recent runs as lightweight JSON summaries (one key metric on each, so the list
  # is scannable as "what came out", not just "that it ran"). Slim columns only - no typed-table loads.
  def index
    runs = AnalysisRun.order(created_at: :desc).limit(30)
                      .select(:id, :status, :progress, :params, :gamma_12, :peak_irf, :peak_horizon,
                              :n_countries, :created_at, :predictor_indicator_id, :response_indicator_id)
                      .includes(:predictor_indicator, :response_indicator)
    render json: runs.map { |r|
      { id: r.id, status: r.status, progress: r.progress,
        n_bootstrap: r.params["n_bootstrap"], start_year: r.params["start_year"], end_year: r.params["end_year"],
        predictor: r.predictor_indicator.display_name,
        response: r.response_indicator&.display_name,
        gamma_12: f(r.gamma_12), peak_irf: f(r.peak_irf), peak_horizon: r.peak_horizon,
        n_countries: r.n_countries, created_at: r.created_at.iso8601 }
    }
  end

  def create
    response  = Indicator.find_by(code: params[:response_code].presence || AnalysisRun::RESPONSE_CODE) # GDP default; any indicator
    predictor = Indicator.find_by(code: params[:predictor_code].to_s)
    return render(json: { error: "Unknown predictor indicator." }, status: :unprocessable_entity) if predictor.nil?
    return render(json: { error: "Unknown response indicator." }, status: :unprocessable_entity) if response.nil?
    # both go through log in pvar.R (must be > 0) AND PVAR is a derivative work, so a NoDerivatives (map-only)
    # licence is barred from compute. The pickers gate this client-side; this is the server-side guard.
    return render(json: { error: "Both variables must be computable (values > 0 and a licence that permits derivatives)." }, status: :unprocessable_entity) unless predictor.computable? && response.computable?

    nb = params[:n_bootstrap].to_i
    nb = 1000 unless AnalysisRun::BOOTSTRAP.include?(nb)
    sy = (params[:start_year].presence || 2000).to_i
    ey = (params[:end_year].presence || 2012).to_i
    return render(json: { error: "End year must be after start year." }, status: :unprocessable_entity) if ey <= sy
    # Bound the window to the data envelope (mirrors the analysis_runs_year_bounds_check DB constraint) so a
    # hostile/buggy client cannot request an absurd panel (DoS) or a write the DB would reject. (harden 2026-06-25)
    return render(json: { error: "Year range must fall within 1..2100." }, status: :unprocessable_entity) if sy < 1 || ey > 2100

    run = AnalysisRun.create!(
      model_spec: ModelSpec.find_by!(code: "pvar_goes_2016"),
      response_indicator: response, predictor_indicator: predictor, seed: 42, status: "pending",
      params: { start_year: sy, end_year: ey, n_lags: 1, n_bootstrap: nb, n_exclude: 10 })
    PvarJob.perform_async(run.id)
    render json: { id: run.id, status: run.status }, status: :created
  end

  def show
    run = AnalysisRun.select(:id, :status, :progress, :error_message, :gamma_12, :p_gamma_12,
                             :peak_irf, :peak_horizon, :n_countries, :n_years, :params,
                             :predictor_indicator_id, :response_indicator_id).find(params[:id])
    body = { id: run.id, status: run.status, progress: run.progress, n_bootstrap: run.params["n_bootstrap"] }
    if run.status == "completed"
      g21 = run.gamma_21  # response -> predictor (see AnalysisRun#gamma_21)
      body.merge!(
        gamma_12: f(run.gamma_12), p_gamma_12: f(run.p_gamma_12),
        gamma_21: f(g21&.coefficient), p_gamma_21: f(g21&.p_value),
        peak_irf: f(run.peak_irf), peak_horizon: run.peak_horizon,
        n_countries: run.n_countries, n_years: run.n_years,
        start_year: run.params["start_year"], end_year: run.params["end_year"],
        predictor: run.predictor_indicator.display_name,
        response: run.response_indicator.display_name,
        irf: run.irf_estimates.order(:horizon).map { |i|
          { horizon: i.horizon, irf: f(i.irf), ci_lower: f(i.ci_lower), ci_upper: f(i.ci_upper) } },
        diagnostics: run.diagnostic_tests.order(:equation, :test_name).map { |d|
          { equation: d.equation, test: d.test_name, statistic: f(d.statistic), p_value: f(d.p_value), df: d.df } })
    elsif run.status == "failed"
      body[:error] = run.error_message
    end
    render json: body
  end

  # Delete a run from the history (typed results cascade via dependent: :delete_all).
  def destroy
    AnalysisRun.find(params[:id]).destroy
    head :no_content
  end

  private

  def f(v) = v.nil? ? nil : v.to_f

  # Lightweight per-IP write throttle (no rack-attack dep; store-agnostic via Rails.cache). Bounds the only
  # two write paths so a client cannot flood the Sidekiq queue / analysis_runs table. (harden 2026-06-25)
  def throttle_writes
    key = "rl:analyses:#{request.remote_ip}"
    count = (THROTTLE_STORE.read(key) || 0) + 1
    THROTTLE_STORE.write(key, count, expires_in: WRITE_RATE_WINDOW)
    render(json: { error: "Too many requests - slow down." }, status: :too_many_requests) if count > WRITE_RATE_LIMIT
  end
end
