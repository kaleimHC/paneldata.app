# WAVE 0 normalizacja mapy licencji (D-064) dla 40+ źródeł.
# DEVIATION vs literal DDL: redistributable/modifiable/share_alike are NULLable here.
#   Reason: the WAVE 0 seed defines a "Custom" row with redist=null/mod=null/sa=null
#   (per-source, unknown). NOT NULL would force a false `false`; NULL = "unknown" is correct.
#   attribution_required stays NOT NULL (seed always provides it).
class CreateLicenses < ActiveRecord::Migration[8.1]
  def change
    create_table :licenses do |t|
      t.text :spdx_code                            # CC-BY-4.0, CC-BY-SA-4.0, ...
      t.text :name, null: false
      t.text :url
      t.boolean :redistributable                   # NULLable (see header)
      t.boolean :modifiable                        # NULLable
      t.boolean :attribution_required, null: false
      t.boolean :share_alike                       # NULLable
    end
    add_index :licenses, :spdx_code, unique: true
  end
end
