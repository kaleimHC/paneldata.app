require "open3"
require "json"
require "tmpdir"
require "fileutils"

# Runs one Panel-VAR estimation: build panel CSV (Rails) -> shell out to Rscript lib/r/pvar.R (R computes) ->
# persist results to PG. : Process.spawn + manual timeout. R4 LANDMINE: the R subprocess is spawned in
# its OWN process group (pgroup: true) and killed by -pgid only - NEVER a broad pkill, because this VPS shares
# its PID namespace with prod containers and host-side R fetchers. : single-thread BLAS via env.
class PvarJob
  include Sidekiq::Job
  sidekiq_options queue: :pvar_jobs, retry: false

  PVAR_R   = Rails.root.join("lib/r/pvar.R").to_s
  TIMEOUT  = 90 * 60   # seconds
  BLAS_ENV = { "OMP_NUM_THREADS" => "1", "OPENBLAS_NUM_THREADS" => "1", "MKL_NUM_THREADS" => "1" }.freeze

  def perform(run_id)
    run = AnalysisRun.find(run_id)
    return if run.terminal?
    run.update!(status: "running", started_at: Time.current, progress: 0, error_message: nil)

    Dir.mktmpdir("pvar") do |dir|
      csv = File.join(dir, "panel.csv")
      out = File.join(dir, "out.json")
      cfg = File.join(dir, "cfg.json")
      log = File.join(dir, "r.log")
      p   = run.params

      panel = PanelBuilder.build(
        response_indicator: run.response_indicator, predictor_indicator: run.predictor_indicator,
        start_year: p["start_year"].to_i, end_year: p["end_year"].to_i, out_path: csv)

      # Min countries depends on bootstrap: the jackknife in pvar.R excludes n_exclude countries per iteration and
      # STOPS if n_exclude >= n_countries (false-green otherwise). n_bootstrap=0 only needs the AB-GMM floor (5).
      nb    = p["n_bootstrap"].to_i
      nx    = (p["n_exclude"] || 10).to_i
      min_n = nb.positive? ? nx + 1 : 5
      if panel.n_countries < min_n
        return fail!(run, "balanced panel too small: #{panel.n_countries} countries (min #{min_n} for #{nb} bootstraps)")
      end

      File.write(cfg, {
        csv_path: csv, output_path: out, n_bootstrap: p["n_bootstrap"].to_i,
        n_exclude: (p["n_exclude"] || 10).to_i, seed: run.seed
      }.to_json)

      run_r!(run, cfg, log)
      result = File.exist?(out) ? JSON.parse(File.read(out)) : { "status" => "failed",
        "error" => "R produced no output; tail: #{File.exist?(log) ? File.read(log)[-400..] : 'n/a'}" }
      persist!(run, result)
    end
  rescue Timeout::Error
    fail!(run, "compute timed out after #{TIMEOUT / 60} min")
  rescue => e
    fail!(run, "#{e.class}: #{e.message}")
  end

  # Spawn R in its OWN process group; on timeout OR Sidekiq::Shutdown (deploy/restart) kill the whole group
  # by -pgid only (R4 LANDMINE: never a broad pkill - this VPS shares its PID namespace with prod containers
  # and host-side R fetchers). A killed run stays status='running' and is requeued by the startup_sweep.
  def run_r!(run, cfg, log)
    pid  = Process.spawn(BLAS_ENV, "Rscript", PVAR_R, cfg, pgroup: true,
                         out: [log, "w"], err: [:child, :out])
    pgid = Process.getpgid(pid)
    deadline = Time.now + TIMEOUT
    last = -1
    begin
      loop do
        _, st = Process.waitpid2(pid, Process::WNOHANG)
        return if st
        raise Timeout::Error if Time.now > deadline
        prog = parse_progress(log)         # live progress: R logs "Iteracja N/M" every 100 bootstraps
        if prog && prog != last
          run.update_columns(progress: prog)
          last = prog
        end
        sleep 1
      end
    rescue Exception # Timeout::Error or Sidekiq::Shutdown - reap the R process group, then re-raise
      Process.kill("-TERM", pgid) rescue nil
      sleep 5
      Process.kill("-KILL", pgid) rescue nil
      Process.waitpid(pid) rescue nil
      raise
    end
  end

  # Latest bootstrap iteration the R worker has logged ("Iteracja N/M"), or nil. Log is small (~few KB).
  def parse_progress(log)
    return nil unless File.exist?(log)
    m = File.read(log).scan(/Iteracja (\d+)\//).last
    m && m[0].to_i
  rescue StandardError
    nil
  end

  def fail!(run, msg)
    run.update!(status: "failed", error_message: msg.to_s[0, 500], finished_at: Time.current)
    nil
  end

  def persist!(run, result)
    return fail!(run, result["error"].to_s) if result["status"] != "completed"

    AnalysisRun.transaction do
      run.gamma_coefficients.delete_all
      run.irf_estimates.delete_all
      run.diagnostic_tests.delete_all
      Array(result["gamma"]).each do |g|
        run.gamma_coefficients.create!(equation: g["equation"], regressor: g["regressor"],
                                       coefficient: g["coefficient"], p_value: g["p_value"])
      end
      Array(result["irf"]).each do |i|
        run.irf_estimates.create!(horizon: i["horizon"], irf: i["irf"],
                                  ci_lower: i["ci_lower"], ci_upper: i["ci_upper"])
      end
      Array(result["diagnostics"]).each do |d|
        run.diagnostic_tests.create!(equation: d["equation"], test_name: d["test_name"],
                                     statistic: d["statistic"], p_value: d["p_value"], df: d["df"])
      end
      run.update!(status: "completed", finished_at: Time.current,
        gamma_12: result["gamma_12"], p_gamma_12: result["p_gamma_12"],
        peak_irf: result["peak_irf"], peak_horizon: result["peak_horizon"],
        n_countries: result["n_countries"], n_years: result["n_years"],
        bootstrap_distributions: result["bootstrap"],
        r_version: result["r_version"], package_versions: result["package_versions"] || {},
        progress: run.params["n_bootstrap"].to_i)
    end
  end
end
