require "test_helper"
require "json"

# Happy-path of the compute pipeline: config params -> AnalysisRun -> PvarJob -> persisted result.
# We never run the real ~90 min Rscript (a PvarJob subclass overrides run_r! to drop a sentinel out.json) and
# we fake PanelBuilder.build (it has its own strict-balance test); this isolates the job's orchestration +
# persist! path. No mocking gem (minitest/mock is not available on minitest 6).
class PvarJobTest < ActiveSupport::TestCase
  SENTINEL = {
    "status" => "completed", "gamma_12" => 0.31913659, "p_gamma_12" => 0.01,
    "peak_irf" => 0.69, "peak_horizon" => 5, "n_countries" => 5, "n_years" => 3,
    "gamma" => [
      { "equation" => "log_efw", "regressor" => "L.log_gdp", "coefficient" => 0.31913659, "p_value" => 0.01 },
      { "equation" => "log_gdp", "regressor" => "L.log_efw", "coefficient" => 0.10, "p_value" => 0.30 }
    ],
    "irf" => [{ "horizon" => 0, "irf" => 0.0, "ci_lower" => nil, "ci_upper" => nil }],
    "diagnostics" => [{ "equation" => "log_gdp", "test_name" => "AR1", "statistic" => -2.5, "p_value" => 0.01, "df" => nil }],
    "r_version" => "stub (test)", "package_versions" => {}
  }.freeze

  # Same job, but the R shell-out writes the sentinel out.json instead of spawning Rscript.
  class StubRJob < PvarJob
    def run_r!(_run, cfg, _log)
      File.write(JSON.parse(File.read(cfg))["output_path"], SENTINEL.to_json)
    end
  end

  test "perform builds the panel, runs R, and persists a completed result" do
    run = AnalysisRun.create!(
      model_spec: model_specs(:pvar),
      response_indicator: indicators(:gdp), predictor_indicator: indicators(:polity),
      seed: 42, status: "pending",
      params: { start_year: 2000, end_year: 2002, n_lags: 1, n_bootstrap: 0, n_exclude: 10 })

    with_stubbed_panel(PanelBuilder::Result.new(csv_path: "/tmp/panel.csv", n_countries: 5, n_years: 3, rows: 15)) do
      StubRJob.new.perform(run.id)
    end

    run.reload
    assert_equal "completed", run.status
    assert_in_delta 0.31913659, run.gamma_12.to_f, 1e-6
    assert_equal 2, run.gamma_coefficients.count
    assert_equal 1, run.irf_estimates.count
    assert_equal 1, run.diagnostic_tests.count
    assert_equal run.gamma_coefficients.find_by(equation: "log_efw", regressor: "L.log_gdp"), run.gamma_21
    assert_not_nil run.finished_at
  end

  test "perform fails the run when the balanced panel is too small for the bootstrap" do
    run = AnalysisRun.create!(
      model_spec: model_specs(:pvar),
      response_indicator: indicators(:gdp), predictor_indicator: indicators(:polity),
      seed: 42, status: "pending",
      params: { start_year: 2000, end_year: 2002, n_lags: 1, n_bootstrap: 1000, n_exclude: 10 })

    # 4 balanced countries but a bootstrapped run needs > n_exclude (>= 11); the job must fail before any R call.
    with_stubbed_panel(PanelBuilder::Result.new(csv_path: "/tmp/panel.csv", n_countries: 4, n_years: 3, rows: 12)) do
      StubRJob.new.perform(run.id)
    end

    run.reload
    assert_equal "failed", run.status
    assert_match(/too small/i, run.error_message)
  end

  private

  # Temporarily replace PanelBuilder.build (a tested collaborator) with a fixed Result, restoring it after.
  def with_stubbed_panel(result)
    original = PanelBuilder.method(:build)
    PanelBuilder.define_singleton_method(:build) { |**| result }
    yield
  ensure
    PanelBuilder.define_singleton_method(:build, original)
  end
end
