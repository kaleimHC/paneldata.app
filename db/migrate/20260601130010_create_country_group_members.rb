# WAVE 0 nadbudowa: join table, composite PK (country_group_id, country_iso3c).
class CreateCountryGroupMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :country_group_members, primary_key: %i[country_group_id country_iso3c] do |t|
      t.references :country_group, null: false, type: :bigint, index: false,
                   foreign_key: { on_delete: :cascade }
      t.column :country_iso3c, "char(3)", null: false
      t.integer :joined_year, limit: 2
      t.integer :left_year, limit: 2
    end
    add_foreign_key :country_group_members, :countries,
                    column: :country_iso3c, primary_key: :iso3c, on_delete: :cascade
    add_index :country_group_members, :country_iso3c
  end
end
