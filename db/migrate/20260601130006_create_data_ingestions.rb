# D-034: provenance - when data was fetched, by which parser version, with what result.
# Kanon nazwa: data_ingestions (NIE import_runs). observations.data_ingestion_id FK -> tu (D-045).
class CreateDataIngestions < ActiveRecord::Migration[8.1]
  def change
    create_table :data_ingestions do |t|
      t.references :source_revision, null: false, type: :bigint,
                   foreign_key: { on_delete: :restrict }
      t.datetime :started_at, null: false, default: -> { "now()" }
      t.datetime :finished_at
      t.text :status, null: false, default: "running"
      t.text :parser_version                       # D-034
      t.integer :rows_inserted, default: 0
      t.integer :rows_updated, default: 0
      t.integer :rows_skipped, default: 0
      t.text :raw_path                             # /srv/paneldata/data/raw/<source>/<version>/
      t.text :error_log
      t.text :triggered_by                         # 'rake task','manual','cron'
    end
    add_check_constraint :data_ingestions,
      "status IN ('running','success','failed','partial')",
      name: "data_ingestions_status_check"
    add_index :data_ingestions, %i[status started_at], name: "idx_ingestions_status"
  end
end
