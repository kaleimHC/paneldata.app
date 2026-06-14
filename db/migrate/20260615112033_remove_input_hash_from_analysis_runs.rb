class RemoveInputHashFromAnalysisRuns < ActiveRecord::Migration[8.1]
  # D-057's input_hash was never wired (no write path); the column stayed NULL and was read by nothing.
  # Drop it instead of shipping a dead, perpetually-NULL field. Reversible (re-adds as text) if a
  # reproducibility-hash path is built later.
  def change
    remove_column :analysis_runs, :input_hash, :text
  end
end
