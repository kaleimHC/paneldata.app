# Widen observations.year CHECK from the business range (1900-2100) to a wide SANITY range.
# Rationale: the data range is per-indicator and dynamic (the slider derives it from MIN/MAX(year));
# the CHECK exists only to block absurd years on the upsert_all path (which bypasses model validations).
# Floor -10000 covers the deepest realistic social-science data (HYDE/OWID population, 10000 BCE).
class WidenObservationsYearCheck < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :observations, name: "observations_year_check"
    add_check_constraint :observations, "year >= -10000 AND year <= 2100", name: "observations_year_check"
  end

  def down
    remove_check_constraint :observations, name: "observations_year_check"
    add_check_constraint :observations, "year >= 1900 AND year <= 2100", name: "observations_year_check"
  end
end
