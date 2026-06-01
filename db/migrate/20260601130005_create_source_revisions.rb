# D-047/D-048: append-only vintage tracking + single "latest" per source via partial unique idx.
# WAVE 0 add: data_source_id FK (org-level link). `source` TEXT zostaje jako denormalized cache (D-047).
class CreateSourceRevisions < ActiveRecord::Migration[8.1]
  def change
    create_table :source_revisions do |t|
      t.references :data_source, null: false, type: :bigint,
                   foreign_key: { on_delete: :restrict }   # NEW FK
      t.text :source, null: false                          # D-047 denormalized cache (e.g. 'wb_wdi')
      t.text :revision_code, null: false                   # e.g. '2025-Q4', 'v16'
      t.date :released_at, null: false
      t.datetime :ingested_at, null: false, default: -> { "now()" }
      t.boolean :is_latest, null: false, default: false
      t.text :notes
    end
    add_index :source_revisions, %i[source revision_code], unique: true  # D-047
    add_index :source_revisions, :source, unique: true,
              where: "is_latest = true", name: "idx_one_latest_per_source" # D-048
  end
end
