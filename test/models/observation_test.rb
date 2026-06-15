require "test_helper"

class ObservationTest < ActiveSupport::TestCase
  test "the 5-tuple country/indicator/year/value_type/source_revision is unique" do
    existing = observations(:gdp_pol_00)
    dup = Observation.new(
      country_iso3c: existing.country_iso3c, indicator: existing.indicator,
      year: existing.year, value_type: existing.value_type,
      source_revision: existing.source_revision, value: 1.0)
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save(validate: false) }
  end

  test "a differing value_type is a distinct observation, not a duplicate" do
    existing = observations(:gdp_pol_00)
    obs = Observation.new(
      country_iso3c: existing.country_iso3c, indicator: existing.indicator,
      year: existing.year, value_type: "estimate",
      source_revision: existing.source_revision, value: 1.0)
    assert obs.save, obs.errors.full_messages.to_sentence
  end

  test "value, year and source_revision are required" do
    obs = Observation.new
    assert_not obs.valid?
    assert obs.errors[:value].any?
    assert obs.errors[:year].any?
    assert obs.errors[:source_revision].any?
  end

  test "obs_status must be a valid SDMX status code" do
    obs = observations(:gdp_pol_00).dup
    obs.obs_status = "Z"
    assert_not obs.valid?
    assert obs.errors[:obs_status].any?
  end
end
