require "test_helper"

class AnalysesControllerTest < ActionDispatch::IntegrationTest
  setup { PvarJob.jobs.clear; AnalysesController::THROTTLE_STORE.clear }

  # ---- create: happy path + guards ----
  test "POST /analyses with a valid loggable pair enqueues a run and returns 201" do
    assert_difference -> { AnalysisRun.count }, 1 do
      assert_difference -> { PvarJob.jobs.size }, 1 do
        post analyses_path, as: :json, params: {
          predictor_code: "owid_co2_per_capita", response_code: "NY.GDP.PCAP.KD",
          start_year: 2000, end_year: 2012, n_bootstrap: 0 }
      end
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert body["id"].present?
    assert_equal "pending", body["status"]
  end

  test "POST /analyses rejects an unknown predictor with 422" do
    assert_no_difference -> { AnalysisRun.count } do
      post analyses_path, as: :json, params: { predictor_code: "NOPE", response_code: "NY.GDP.PCAP.KD" }
    end
    assert_response :unprocessable_entity
  end

  test "POST /analyses rejects an unknown response with 422" do
    post analyses_path, as: :json, params: { predictor_code: "owid_co2_per_capita", response_code: "NOPE" }
    assert_response :unprocessable_entity
  end

  test "POST /analyses rejects a non-loggable predictor with 422" do
    post analyses_path, as: :json, params: { predictor_code: "POLITY5", response_code: "NY.GDP.PCAP.KD" }
    assert_response :unprocessable_entity
  end

  test "POST /analyses rejects end_year <= start_year with 422" do
    post analyses_path, as: :json, params: {
      predictor_code: "owid_co2_per_capita", response_code: "NY.GDP.PCAP.KD",
      start_year: 2012, end_year: 2000 }
    assert_response :unprocessable_entity
  end

  # ---- show ----
  test "GET /analyses/:id for a completed run returns the full result shape" do
    get analysis_path(analysis_runs(:completed))
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "completed", body["status"]
    assert_in_delta 0.31913659, body["gamma_12"].to_f, 1e-8
    assert_in_delta 0.31913659, body["gamma_21"].to_f, 1e-8   # log_efw / L.log_gdp pair
    assert_equal 2, body["irf"].size
    assert_equal 2, body["diagnostics"].size
    assert_not body.key?("bootstrap_distributions")           # hot path must not ship the cold blob
  end

  test "GET /analyses/:id for a running run returns a slim body" do
    get analysis_path(analysis_runs(:running))
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "running", body["status"]
    assert_not body.key?("irf")
  end

  # ---- index ----
  test "GET /analyses lists recent runs as JSON summaries" do
    get analyses_path, as: :json
    assert_response :success
    runs = JSON.parse(response.body)
    assert_kind_of Array, runs
    assert(runs.any? { |r| r["status"] == "completed" })
  end

  # ---- destroy ----
  test "DELETE /analyses/:id removes the run and cascades its result rows" do
    run = analysis_runs(:completed)
    assert_difference(
      { -> { AnalysisRun.count } => -1,
        -> { GammaCoefficient.count } => -run.gamma_coefficients.count,
        -> { IrfEstimate.count } => -run.irf_estimates.count,
        -> { DiagnosticTest.count } => -run.diagnostic_tests.count }) do
      delete analysis_path(run)
    end
    assert_response :no_content
  end

  # ---- create: hardening guards (2026-06-25) ----
  test "POST /analyses rejects an out-of-range year window with 422" do
    assert_no_difference -> { AnalysisRun.count } do
      post analyses_path, as: :json, params: {
        predictor_code: "owid_co2_per_capita", response_code: "NY.GDP.PCAP.KD",
        start_year: 2000, end_year: 3000 }
    end
    assert_response :unprocessable_entity
  end

  test "AnalysisRun rejects params outside the sanctioned envelope (defence in depth)" do
    run = AnalysisRun.new(
      model_spec: ModelSpec.find_by!(code: "pvar_goes_2016"),
      response_indicator: indicators(:gdp), predictor_indicator: indicators(:co2),
      seed: 42, status: "pending",
      params: { start_year: 2000, end_year: 3000, n_lags: 1, n_bootstrap: 7, n_exclude: 10 })
    assert_not run.valid?
    assert run.errors[:params].any?
  end

  test "POST /analyses is rate-limited per IP" do
    # 20 unknown-predictor posts pass the throttle (each 422s in the action, no run created); the 21st trips it.
    21.times { post analyses_path, as: :json, params: { predictor_code: "NOPE" } }
    assert_response :too_many_requests
  end
end
