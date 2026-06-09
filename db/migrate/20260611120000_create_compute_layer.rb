# Compute layer (UD-14): live Panel-VAR runs. Slim analysis_runs as the run record + state machine
# (manual enum + CHECK, mirroring DataIngestion - no aasm), bootstrap blob inline JSONB (D-108 Option B,
# polling reads via .select - no vertical partitioning at portfolio scale), and minimal typed result
# tables (gamma / IRF / diagnostics) for queryable artifacts. Estimator: plm::pgmm onestep FD (D-138).
class CreateComputeLayer < ActiveRecord::Migration[8.1]
  def change
    # Registry of econometric model definitions (PVAR_Goes_2016, future OLS/SVAR).
    create_table :model_specs do |t|
      t.text :code, null: false                    # 'pvar_goes_2016'
      t.text :name, null: false
      t.text :description
      t.text :estimator                            # 'plm::pgmm onestep FD (Goes 2016)'
      t.jsonb :defaults, default: {}, null: false  # {n_lags, n_bootstrap, n_exclude, ci_z, cholesky_order}
      t.datetime :created_at, null: false, default: -> { "now()" }
    end
    add_index :model_specs, :code, unique: true

    # One row per user "Run" click. Slim/hot: status + progress + denormalized result scalars are read by
    # the 2s polling endpoint (.select); the bootstrap_distributions blob is read once on result display.
    create_table :analysis_runs do |t|
      t.bigint :model_spec_id, null: false
      t.bigint :response_indicator_id, null: false   # GDP per capita (hardcoded this MVP, still stored)
      t.bigint :predictor_indicator_id, null: false  # user-chosen institution/predictor
      t.jsonb :params, default: {}, null: false      # {start_year, end_year, n_lags, n_bootstrap}
      t.text :status, default: "pending", null: false
      t.integer :progress, default: 0, null: false   # bootstrap iterations completed (0..n_bootstrap)
      t.text :error_message

      # denormalized result scalars (hot - list/index display, no JSON parse)
      t.decimal :gamma_12, precision: 30, scale: 10
      t.decimal :p_gamma_12, precision: 30, scale: 10
      t.decimal :peak_irf, precision: 30, scale: 10
      t.integer :peak_horizon
      t.integer :n_countries
      t.integer :n_years

      # cold blob - bootstrap IRF/gamma matrices (D-108 Option B: inline JSONB, never SELECT *)
      t.jsonb :bootstrap_distributions

      # reproducibility metadata (D-035): pinned for credibility
      t.integer :seed, default: 42, null: false
      t.text :r_version
      t.jsonb :package_versions, default: {}, null: false
      t.text :input_hash                              # formatC-based hash of input panel (D-057)

      t.datetime :started_at
      t.datetime :finished_at
      t.datetime :created_at, null: false, default: -> { "now()" }
    end
    add_index :analysis_runs, [:status, :created_at], name: "idx_analysis_runs_status"
    add_index :analysis_runs, :params, using: :gin, name: "idx_analysis_runs_params"
    add_index :analysis_runs, :model_spec_id
    add_index :analysis_runs, :predictor_indicator_id
    add_check_constraint :analysis_runs,
      "status = ANY (ARRAY['pending'::text, 'running'::text, 'completed'::text, 'failed'::text])",
      name: "analysis_runs_status_check"

    # Typed result: 2x2 autoregression matrix Gamma (4 rows per run).
    create_table :gamma_coefficients do |t|
      t.bigint :analysis_run_id, null: false
      t.text :equation, null: false                  # 'log_gdp' | 'log_efw' (LHS variable)
      t.text :regressor, null: false                 # 'L.log_gdp' | 'L.log_efw'
      t.decimal :coefficient, precision: 30, scale: 10, null: false
      t.decimal :p_value, precision: 30, scale: 10
    end
    add_index :gamma_coefficients, :analysis_run_id

    # Typed result: IRF path (response of GDP to a 1pp predictor shock), 11 rows per run (h=0..10).
    create_table :irf_estimates do |t|
      t.bigint :analysis_run_id, null: false
      t.integer :horizon, null: false                # 0..10
      t.decimal :irf, precision: 30, scale: 10, null: false
      t.decimal :ci_lower, precision: 30, scale: 10  # bootstrap 90% CI (nil if n_bootstrap=0)
      t.decimal :ci_upper, precision: 30, scale: 10
    end
    add_index :irf_estimates, [:analysis_run_id, :horizon]

    # Typed result: GMM diagnostics per equation (AR1/AR2/Sargan).
    create_table :diagnostic_tests do |t|
      t.bigint :analysis_run_id, null: false
      t.text :equation, null: false                  # 'log_gdp' | 'log_efw'
      t.text :test_name, null: false                 # 'AR1' | 'AR2' | 'Sargan'
      t.decimal :statistic, precision: 30, scale: 10
      t.decimal :p_value, precision: 30, scale: 10
      t.integer :df
    end
    add_index :diagnostic_tests, :analysis_run_id
  end
end
