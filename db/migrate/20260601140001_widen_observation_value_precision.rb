# D-164 (amends D-045): NUMERIC(20,10) overflows on absolute monetary aggregates
# (World GDP 2024 = 1.1e14 = 15 integer digits; max for (20,10) is 10). Widen to (30,10):
# 20 integer digits (~1e20) headroom, 10 fractional places preserved (D-045 precision intent).
class WidenObservationValuePrecision < ActiveRecord::Migration[8.1]
  def up
    change_column :observations, :value, :decimal, precision: 30, scale: 10, null: false
    change_column :observations, :std_error, :decimal, precision: 30, scale: 10
  end

  def down
    # Safe only pre-load (narrowing fails if any stored value exceeds 1e10).
    change_column :observations, :value, :decimal, precision: 20, scale: 10, null: false
    change_column :observations, :std_error, :decimal, precision: 20, scale: 10
  end
end
