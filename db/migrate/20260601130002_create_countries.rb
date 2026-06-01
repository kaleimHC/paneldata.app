# D-053: countries keyed by iso3c CHAR(3) (NOT surrogate id) + entity_type ENUM-as-check.
# WAVE 0 additions: iso2, m49, wb_income, oecd/eu/un flags, alt_codes JSONB.
class CreateCountries < ActiveRecord::Migration[8.1]
  def up
    create_table :countries, id: false do |t|
      t.column :iso3c, "char(3)", null: false          # D-053 PK (set below)
      t.column :iso2, "char(2)"                         # ADD (WAVE 0)
      t.integer :m49, limit: 2                          # ADD (UN numeric, SMALLINT)
      t.text :name, null: false                         # kanon
      t.text :name_local                                # ADD
      t.text :region                                    # kanon impl
      t.text :subregion                                 # kanon impl
      t.text :wb_income                                 # ADD
      t.text :entity_type, null: false, default: "country" # D-053
      t.boolean :oecd_member, null: false, default: false  # ADD
      t.boolean :eu_member, null: false, default: false    # ADD
      t.boolean :un_member, null: false, default: false    # ADD
      t.jsonb :alt_codes, null: false, default: {}      # ADD: {polity:"POL", vdem:22, ...}
      t.datetime :created_at, null: false, default: -> { "now()" }
    end
    execute "ALTER TABLE countries ADD CONSTRAINT countries_pkey PRIMARY KEY (iso3c)"
    add_check_constraint :countries,
      "entity_type IN ('country','aggregate','subnational','historical')",
      name: "countries_entity_type_check"                # D-053
    add_index :countries, :iso2, unique: true
    add_index :countries, :m49, unique: true
    add_index :countries, :entity_type, name: "idx_countries_type" # D-053
    add_index :countries, :alt_codes, using: :gin, name: "idx_countries_alt_gin"
  end

  def down
    drop_table :countries
  end
end
