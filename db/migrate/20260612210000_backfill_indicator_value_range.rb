# D-191: populate the (until now empty) value_min/value_max caches so the analysis picker can gate the predictor
# on loggability (value_min > 0). Runs on deploy via db:prepare; idempotent and cheap to re-run.
class BackfillIndicatorValueRange < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    Indicator.backfill_value_range!
  end

  def down
    # Caches only; leave them in place (recomputed by the backfill task on next ingest).
  end
end
