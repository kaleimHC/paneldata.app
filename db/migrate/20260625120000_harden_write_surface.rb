# STAGED in /tmp — copy into db/migrate/ as the deploy user (keep ownership), then db:migrate.
# Hardens the only user-driven write table (analysis_runs) + the worker-written result tables.
# Every constraint verified orphan-/dup-/violation-free on DEV by the 2026-06-25 integrity probe.
class HardenWriteSurface < ActiveRecord::Migration[8.1]
  def change
    # (1) Referential integrity that was missing despite null:false columns.
    add_foreign_key :analysis_runs, :indicators, column: :predictor_indicator_id, on_delete: :restrict
    add_foreign_key :analysis_runs, :indicators, column: :response_indicator_id, on_delete: :restrict
    add_foreign_key :analysis_runs, :model_specs, on_delete: :restrict
    add_foreign_key :gamma_coefficients, :analysis_runs, on_delete: :cascade
    add_foreign_key :irf_estimates,      :analysis_runs, on_delete: :cascade
    add_foreign_key :diagnostic_tests,   :analysis_runs, on_delete: :cascade

    # (2) Result-row uniqueness — a re-run deletes+reinserts; this blocks silent duplicates.
    add_index :gamma_coefficients, [:analysis_run_id, :equation, :regressor], unique: true, name: "idx_gamma_unique"
    add_index :irf_estimates,      [:analysis_run_id, :horizon], unique: true, name: "idx_irf_unique"
    add_index :diagnostic_tests,   [:analysis_run_id, :equation, :test_name], unique: true, name: "idx_diag_unique"

    # (3) Defence-in-depth bounds on params a button can submit — mirrors AnalysesController guards so
    #     even a direct/bypass write to analysis_runs stays within the sanctioned envelope.
    add_check_constraint :analysis_runs,
      "(params->>'n_bootstrap') IS NULL OR (params->>'n_bootstrap')::int IN (0,100,1000)",
      name: "analysis_runs_n_bootstrap_check"
    add_check_constraint :analysis_runs,
      "(params->>'n_exclude') IS NULL OR (params->>'n_exclude')::int BETWEEN 0 AND 50",
      name: "analysis_runs_n_exclude_check"
    add_check_constraint :analysis_runs,
      "(params->>'start_year') IS NULL OR (params->>'end_year') IS NULL OR " \
      "((params->>'start_year')::int >= 1 AND (params->>'end_year')::int <= 2100 " \
      "AND (params->>'end_year')::int > (params->>'start_year')::int)",
      name: "analysis_runs_year_bounds_check"
  end
end
