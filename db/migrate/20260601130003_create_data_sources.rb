# WAVE 0 nadbudowa: organization-level source (WB -> {WDI, WGI} as separate source_revisions).
# Kanon trzymał source jako indicators.source TEXT (denormalized) - to normalizacja warstwy wyżej.
class CreateDataSources < ActiveRecord::Migration[8.1]
  def change
    create_table :data_sources do |t|
      t.text :code, null: false                    # 'wb_wdi','wb_wgi','vdem','undp_hdi'...
      t.text :name, null: false                    # 'World Bank WDI'
      t.text :organization                         # 'World Bank Group'
      t.column :country_origin, "char(3)"          # FK -> countries(iso3c)
      t.text :homepage_url
      t.text :api_base
      t.text :pillar
      t.text :bias_note
      t.datetime :created_at, null: false, default: -> { "now()" }
    end
    add_index :data_sources, :code, unique: true
    add_check_constraint :data_sources,
      "pillar IS NULL OR pillar IN ('un','multilateral','non_anglo','regional','composite','western','conflict','national')",
      name: "data_sources_pillar_check"
    add_foreign_key :data_sources, :countries, column: :country_origin, primary_key: :iso3c
  end
end
