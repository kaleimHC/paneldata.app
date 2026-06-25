# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_25_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "value_type_enum", ["raw", "estimate", "percentile", "index", "rank", "categorical_code"]

  create_table "analysis_runs", force: :cascade do |t|
    t.jsonb "bootstrap_distributions"
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.text "error_message"
    t.datetime "finished_at"
    t.decimal "gamma_12", precision: 30, scale: 10
    t.bigint "model_spec_id", null: false
    t.integer "n_countries"
    t.integer "n_years"
    t.decimal "p_gamma_12", precision: 30, scale: 10
    t.jsonb "package_versions", default: {}, null: false
    t.jsonb "params", default: {}, null: false
    t.integer "peak_horizon"
    t.decimal "peak_irf", precision: 30, scale: 10
    t.bigint "predictor_indicator_id", null: false
    t.integer "progress", default: 0, null: false
    t.text "r_version"
    t.bigint "response_indicator_id", null: false
    t.integer "seed", default: 42, null: false
    t.datetime "started_at"
    t.text "status", default: "pending", null: false
    t.index ["model_spec_id"], name: "index_analysis_runs_on_model_spec_id"
    t.index ["params"], name: "idx_analysis_runs_params", using: :gin
    t.index ["predictor_indicator_id"], name: "index_analysis_runs_on_predictor_indicator_id"
    t.index ["status", "created_at"], name: "idx_analysis_runs_status"
    t.check_constraint "(params ->> 'n_bootstrap'::text) IS NULL OR (((params ->> 'n_bootstrap'::text)::integer) = ANY (ARRAY[0, 100, 1000]))", name: "analysis_runs_n_bootstrap_check"
    t.check_constraint "(params ->> 'n_exclude'::text) IS NULL OR ((params ->> 'n_exclude'::text)::integer) >= 0 AND ((params ->> 'n_exclude'::text)::integer) <= 50", name: "analysis_runs_n_exclude_check"
    t.check_constraint "(params ->> 'start_year'::text) IS NULL OR (params ->> 'end_year'::text) IS NULL OR ((params ->> 'start_year'::text)::integer) >= 1 AND ((params ->> 'end_year'::text)::integer) <= 2100 AND ((params ->> 'end_year'::text)::integer) > ((params ->> 'start_year'::text)::integer)", name: "analysis_runs_year_bounds_check"
    t.check_constraint "status = ANY (ARRAY['pending'::text, 'running'::text, 'completed'::text, 'failed'::text])", name: "analysis_runs_status_check"
  end

  create_table "countries", primary_key: "iso3c", id: { type: :string, limit: 3 }, force: :cascade do |t|
    t.jsonb "alt_codes", default: {}, null: false
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.text "entity_type", default: "country", null: false
    t.boolean "eu_member", default: false, null: false
    t.string "iso2", limit: 2
    t.integer "m49", limit: 2
    t.text "name", null: false
    t.text "name_local"
    t.boolean "oecd_member", default: false, null: false
    t.text "region"
    t.text "subregion"
    t.boolean "un_member", default: false, null: false
    t.text "wb_income"
    t.index ["alt_codes"], name: "idx_countries_alt_gin", using: :gin
    t.index ["entity_type"], name: "idx_countries_type"
    t.index ["iso2"], name: "index_countries_on_iso2", unique: true
    t.index ["m49"], name: "index_countries_on_m49", unique: true
    t.check_constraint "entity_type = ANY (ARRAY['country'::text, 'aggregate'::text, 'subnational'::text, 'historical'::text])", name: "countries_entity_type_check"
  end

  create_table "country_group_members", primary_key: ["country_group_id", "country_iso3c"], force: :cascade do |t|
    t.bigint "country_group_id", null: false
    t.string "country_iso3c", limit: 3, null: false
    t.integer "joined_year", limit: 2
    t.integer "left_year", limit: 2
    t.index ["country_iso3c"], name: "index_country_group_members_on_country_iso3c"
  end

  create_table "country_groups", force: :cascade do |t|
    t.text "code", null: false
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.text "description"
    t.text "name", null: false
    t.index ["code"], name: "index_country_groups_on_code", unique: true
  end

  create_table "data_ingestions", force: :cascade do |t|
    t.text "error_log"
    t.datetime "finished_at"
    t.text "parser_version"
    t.text "raw_path"
    t.integer "rows_inserted", default: 0
    t.integer "rows_skipped", default: 0
    t.integer "rows_updated", default: 0
    t.bigint "source_revision_id", null: false
    t.datetime "started_at", default: -> { "now()" }, null: false
    t.text "status", default: "running", null: false
    t.text "triggered_by"
    t.index ["source_revision_id"], name: "index_data_ingestions_on_source_revision_id"
    t.index ["status", "started_at"], name: "idx_ingestions_status"
    t.check_constraint "status = ANY (ARRAY['running'::text, 'success'::text, 'failed'::text, 'partial'::text])", name: "data_ingestions_status_check"
  end

  create_table "data_sources", force: :cascade do |t|
    t.text "api_base"
    t.text "bias_note"
    t.text "code", null: false
    t.string "country_origin", limit: 3
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.text "homepage_url"
    t.text "name", null: false
    t.text "organization"
    t.text "pillar"
    t.index ["code"], name: "index_data_sources_on_code", unique: true
    t.check_constraint "pillar IS NULL OR (pillar = ANY (ARRAY['un'::text, 'multilateral'::text, 'non_anglo'::text, 'regional'::text, 'composite'::text, 'western'::text, 'conflict'::text, 'national'::text, 'academic_consortium'::text]))", name: "data_sources_pillar_check"
  end

  create_table "diagnostic_tests", force: :cascade do |t|
    t.bigint "analysis_run_id", null: false
    t.integer "df"
    t.text "equation", null: false
    t.decimal "p_value", precision: 30, scale: 10
    t.decimal "statistic", precision: 30, scale: 10
    t.text "test_name", null: false
    t.index ["analysis_run_id", "equation", "test_name"], name: "idx_diag_unique", unique: true
    t.index ["analysis_run_id"], name: "index_diagnostic_tests_on_analysis_run_id"
  end

  create_table "gamma_coefficients", force: :cascade do |t|
    t.bigint "analysis_run_id", null: false
    t.decimal "coefficient", precision: 30, scale: 10, null: false
    t.text "equation", null: false
    t.decimal "p_value", precision: 30, scale: 10
    t.text "regressor", null: false
    t.index ["analysis_run_id", "equation", "regressor"], name: "idx_gamma_unique", unique: true
    t.index ["analysis_run_id"], name: "index_gamma_coefficients_on_analysis_run_id"
  end

  create_table "indicators", force: :cascade do |t|
    t.string "ancestry", collation: "C"
    t.text "code", null: false
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.string "data_mode"
    t.bigint "data_source_id"
    t.text "description"
    t.text "dimension"
    t.string "direction", limit: 1
    t.text "frequency", default: "annual", null: false
    t.boolean "is_active", default: true, null: false
    t.integer "level", default: 0, null: false
    t.string "license"
    t.bigint "license_id"
    t.text "methodology_url"
    t.text "name", null: false
    t.text "scale_note"
    t.text "source", null: false
    t.text "source_url"
    t.string "transform_default"
    t.text "unit"
    t.decimal "value_max"
    t.decimal "value_min"
    t.index ["ancestry"], name: "index_indicators_on_ancestry"
    t.index ["code"], name: "index_indicators_on_code", unique: true
    t.index ["data_source_id"], name: "idx_indicators_data_src", where: "(is_active = true)"
    t.index ["dimension"], name: "idx_indicators_dimension", where: "(is_active = true)"
    t.index ["source"], name: "idx_indicators_source", where: "(is_active = true)"
    t.check_constraint "direction IS NULL OR (direction = ANY (ARRAY['+'::bpchar, '-'::bpchar]))", name: "indicators_direction_check"
    t.check_constraint "frequency = ANY (ARRAY['annual'::text, 'quarterly'::text, 'monthly'::text])", name: "indicators_frequency_check"
    t.check_constraint "transform_default IS NULL OR (transform_default::text = ANY (ARRAY['log'::character varying, 'levels'::character varying, 'none'::character varying]::text[]))", name: "indicators_transform_default_check"
  end

  create_table "irf_estimates", force: :cascade do |t|
    t.bigint "analysis_run_id", null: false
    t.decimal "ci_lower", precision: 30, scale: 10
    t.decimal "ci_upper", precision: 30, scale: 10
    t.integer "horizon", null: false
    t.decimal "irf", precision: 30, scale: 10, null: false
    t.index ["analysis_run_id", "horizon"], name: "idx_irf_unique", unique: true
    t.index ["analysis_run_id", "horizon"], name: "index_irf_estimates_on_analysis_run_id_and_horizon"
  end

  create_table "licenses", force: :cascade do |t|
    t.boolean "attribution_required", null: false
    t.boolean "modifiable"
    t.text "name", null: false
    t.boolean "redistributable"
    t.boolean "share_alike"
    t.text "spdx_code"
    t.text "url"
    t.index ["spdx_code"], name: "index_licenses_on_spdx_code", unique: true
  end

  create_table "model_specs", force: :cascade do |t|
    t.text "code", null: false
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.jsonb "defaults", default: {}, null: false
    t.text "description"
    t.text "estimator"
    t.text "name", null: false
    t.index ["code"], name: "index_model_specs_on_code", unique: true
  end

  create_table "observations", force: :cascade do |t|
    t.string "country_iso3c", limit: 3, null: false
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.bigint "data_ingestion_id"
    t.text "imputation_method"
    t.bigint "indicator_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "obs_status", default: "A", null: false
    t.text "source_revision", null: false
    t.decimal "std_error", precision: 30, scale: 10
    t.decimal "value", precision: 30, scale: 10, null: false
    t.enum "value_type", default: "raw", null: false, enum_type: "value_type_enum"
    t.integer "year", null: false
    t.index ["country_iso3c", "indicator_id", "year", "value_type", "source_revision"], name: "index_observations_uniqueness", unique: true
    t.index ["country_iso3c", "year"], name: "idx_obs_country_year"
    t.index ["indicator_id", "obs_status"], name: "idx_obs_status", where: "((obs_status)::text <> 'A'::text)"
    t.index ["indicator_id", "year"], name: "idx_obs_indicator_year"
    t.index ["metadata"], name: "idx_obs_metadata_gin", using: :gin
    t.check_constraint "imputation_method IS NULL OR (imputation_method = ANY (ARRAY['locf'::text, 'linear_interp'::text, 'mean_substitution'::text]))", name: "observations_imputation_method_check"
    t.check_constraint "obs_status::text = ANY (ARRAY['A'::character varying, 'b'::character varying, 'd'::character varying, 'e'::character varying, 'f'::character varying, 'i'::character varying, 'm'::character varying, 'n'::character varying, 'p'::character varying, 'u'::character varying]::text[])", name: "observations_obs_status_check"
    t.check_constraint "year >= '-10000'::integer AND year <= 2100", name: "observations_year_check"
  end

  create_table "source_revisions", force: :cascade do |t|
    t.bigint "data_source_id", null: false
    t.datetime "ingested_at", default: -> { "now()" }, null: false
    t.boolean "is_latest", default: false, null: false
    t.text "notes"
    t.date "released_at", null: false
    t.text "revision_code", null: false
    t.text "source", null: false
    t.index ["data_source_id"], name: "index_source_revisions_on_data_source_id"
    t.index ["source", "revision_code"], name: "index_source_revisions_on_source_and_revision_code", unique: true
    t.index ["source"], name: "idx_one_latest_per_source", unique: true, where: "(is_latest = true)"
  end

  add_foreign_key "analysis_runs", "indicators", column: "predictor_indicator_id", on_delete: :restrict
  add_foreign_key "analysis_runs", "indicators", column: "response_indicator_id", on_delete: :restrict
  add_foreign_key "analysis_runs", "model_specs", on_delete: :restrict
  add_foreign_key "country_group_members", "countries", column: "country_iso3c", primary_key: "iso3c", on_delete: :cascade
  add_foreign_key "country_group_members", "country_groups", on_delete: :cascade
  add_foreign_key "data_ingestions", "source_revisions", on_delete: :restrict
  add_foreign_key "data_sources", "countries", column: "country_origin", primary_key: "iso3c"
  add_foreign_key "diagnostic_tests", "analysis_runs", on_delete: :cascade
  add_foreign_key "gamma_coefficients", "analysis_runs", on_delete: :cascade
  add_foreign_key "indicators", "data_sources"
  add_foreign_key "indicators", "licenses"
  add_foreign_key "irf_estimates", "analysis_runs", on_delete: :cascade
  add_foreign_key "observations", "countries", column: "country_iso3c", primary_key: "iso3c"
  add_foreign_key "observations", "data_ingestions"
  add_foreign_key "observations", "indicators", on_delete: :restrict
  add_foreign_key "source_revisions", "data_sources", on_delete: :restrict
end
