# WAVE 0 nadbudowa: complementary to D-053 entity_type. A group = kolekcja członków (EU27, BRICS);
# entity_type='aggregate' = gotowy agregat-byt publikowany przez źródło. Oba use case żyją.
class CreateCountryGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :country_groups do |t|
      t.text :code, null: false                    # 'EU27','ASEAN','BRICS','OECD','G20'
      t.text :name, null: false
      t.text :description
      t.datetime :created_at, null: false, default: -> { "now()" }
    end
    add_index :country_groups, :code, unique: true
  end
end
