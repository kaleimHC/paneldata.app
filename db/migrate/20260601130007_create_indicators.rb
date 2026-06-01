# D-046 + D-100 + D-139/D-140. Hierarchy via `ancestry` gem (materialized path).
# DEVIATION vs literal DDL: uses `ancestry` (string) column, NOT `parent_id` self-FK.
#   Reason: has_ancestry (canon, reaffirmed D-139/D-140) is a materialized-path mechanism - it
#   cannot operate on parent_id. The DDL's parent_id+has_ancestry was internally contradictory.
#   Canon `level` (D-046) retained. collation "C" per ancestry PG guidance (correct LIKE ordering).
# Two "license" columns by design: `license` VARCHAR (D-100 denormalized cache) + `license_id` FK.
class CreateIndicators < ActiveRecord::Migration[8.1]
  def change
    create_table :indicators do |t|
      t.text :code, null: false                    # D-046
      t.string :ancestry, collation: "C"           # ancestry gem (D-046/D-139/D-140)
      t.text :name, null: false                    # D-046
      t.text :name_pl                              # ADD
      t.text :source, null: false                  # D-046 denormalized cache
      t.references :data_source, type: :bigint, foreign_key: true, index: false # NEW FK
      t.text :source_url                           # D-046
      t.text :unit                                 # D-046
      t.text :scale_note                           # ADD
      t.column :direction, "char(1)"               # D-046
      t.decimal :value_min                         # D-046
      t.decimal :value_max                         # D-046
      t.text :methodology_url                      # D-046
      t.text :description                          # D-046
      t.string :license                            # D-100 denormalized cache
      t.references :license, type: :bigint, foreign_key: { to_table: :licenses }, index: false # NEW FK (license_id)
      t.string :data_mode                          # D-100
      t.string :transform_default                  # D-100 (log/levels/none)
      t.text :frequency, null: false, default: "annual" # ADD
      t.text :dimension                            # ADD (economic/governance/...)
      t.integer :level, null: false, default: 0    # D-046 (manual hierarchy level)
      t.boolean :is_active, null: false, default: true  # D-046
      t.datetime :created_at, null: false, default: -> { "now()" }
    end
    add_index :indicators, :code, unique: true                                   # D-046
    add_index :indicators, :ancestry                                             # ancestry gem
    add_check_constraint :indicators, "direction IS NULL OR direction IN ('+','-')",
      name: "indicators_direction_check"
    add_check_constraint :indicators,
      "transform_default IS NULL OR transform_default IN ('log','levels','none')",
      name: "indicators_transform_default_check"                                 # D-100
    add_check_constraint :indicators, "frequency IN ('annual','quarterly','monthly')",
      name: "indicators_frequency_check"
    add_index :indicators, :source, where: "is_active = true", name: "idx_indicators_source"        # D-046
    add_index :indicators, :data_source_id, where: "is_active = true", name: "idx_indicators_data_src"
    add_index :indicators, :dimension, where: "is_active = true", name: "idx_indicators_dimension"
  end
end
