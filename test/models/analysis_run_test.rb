require "test_helper"

class AnalysisRunTest < ActiveSupport::TestCase
  test "terminal? is true only for completed and failed" do
    run = analysis_runs(:completed)
    AnalysisRun::STATUSES.each do |s|
      run.status = s
      assert_equal %w[completed failed].include?(s), run.terminal?, "terminal? wrong for status #{s}"
    end
  end

  test "status must be one of STATUSES" do
    run = analysis_runs(:running)
    run.status = "bogus"
    assert_not run.valid?
    assert run.errors[:status].any?
  end

  test "destroying a run cascades to its typed result rows (dependent: :delete_all)" do
    run = analysis_runs(:completed)
    g = run.gamma_coefficients.count
    i = run.irf_estimates.count
    d = run.diagnostic_tests.count
    assert_operator g, :>, 0, "fixture should give the completed run gamma rows"

    assert_difference({ -> { GammaCoefficient.count } => -g,
                        -> { IrfEstimate.count } => -i,
                        -> { DiagnosticTest.count } => -d }) do
      run.destroy
    end
  end

  test "gamma_21 returns the log_efw / L.log_gdp coefficient (response -> predictor)" do
    assert_equal gamma_coefficients(:completed_efw_lgdp), analysis_runs(:completed).gamma_21
  end

  # Guards the DRY single-source: the component/service aliases must track AnalysisRun / PanelBuilder.
  # Referencing those classes here also forces them to load, so a broken alias fails the suite locally
  # (the app does not eager-load in the test env).
  test "PVAR config constants are single-sourced" do
    assert_equal AnalysisRun::RESPONSE_CODE, RunConfigComponent::RESPONSE_CODE
    assert_equal AnalysisRun::BOOTSTRAP, RunConfigComponent::BOOTSTRAP
  end
end
