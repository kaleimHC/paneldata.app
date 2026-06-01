# D-045 (Strict typed) + D-101 (obs_status SDMX replaces is_imputed). KANON - surrogate id PK,
# 5-col UNIQUE, value NUMERIC(20,10), value_type PG ENUM, metadata JSONB, created_at only.
class CreateObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :observations do |t|
      t.column :country_iso3c, "char(3)", null: false                 # D-045 FK -> countries(iso3c)
      t.references :indicator, null: false, type: :bigint, index: false,
                   foreign_key: { on_delete: :restrict }              # D-045
      t.integer :year, null: false                                    # D-045
      t.decimal :value, precision: 20, scale: 10, null: false         # D-045
      t.enum :value_type, enum_type: "value_type_enum", null: false, default: "raw" # D-045
      t.decimal :std_error, precision: 20, scale: 10                  # D-045
      t.string :obs_status, null: false, default: "A"                 # D-101 (SDMX), replaces is_imputed
      t.text :imputation_method                                       # D-045
      t.text :source_revision, null: false                           # D-045 denormalized vintage
      t.references :data_ingestion, type: :bigint, index: false, foreign_key: true # D-045
      t.jsonb :metadata, null: false, default: {}                    # D-045 escape hatch
      t.datetime :created_at, null: false, default: -> { "now()" }   # D-045 (no updated_at)
    end
    add_foreign_key :observations, :countries, column: :country_iso3c, primary_key: :iso3c # D-045
    add_check_constraint :observations, "year BETWEEN 1900 AND 2100",
      name: "observations_year_check"                                 # D-045/D-054
    add_check_constraint :observations,
      "obs_status IN ('A','b','d','e','f','i','m','n','p','u')",
      name: "observations_obs_status_check"                           # D-101
    add_check_constraint :observations,
      "imputation_method IS NULL OR imputation_method IN ('locf','linear_interp','mean_substitution')",
      name: "observations_imputation_method_check"                    # D-045
    add_index :observations, %i[country_iso3c indicator_id year value_type source_revision],
      unique: true, name: "index_observations_uniqueness"             # D-045 (5-col UNIQUE)
    add_index :observations, %i[indicator_id year], name: "idx_obs_indicator_year"  # D-045
    add_index :observations, %i[country_iso3c year], name: "idx_obs_country_year"    # D-045
    add_index :observations, %i[indicator_id obs_status],
      where: "obs_status <> 'A'", name: "idx_obs_status"              # D-101 (was is_imputed)
    add_index :observations, :metadata, using: :gin, name: "idx_obs_metadata_gin"   # D-045
  end
end
