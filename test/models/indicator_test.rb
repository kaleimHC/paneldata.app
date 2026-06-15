require "test_helper"

class IndicatorTest < ActiveSupport::TestCase
  test "loggable? truth table" do
    assert indicators(:gdp).loggable?,          "value_min > 0 is loggable"
    assert indicators(:co2).loggable?,          "value_min > 0 is loggable"
    assert_not indicators(:polity).loggable?,   "value_min <= 0 is not loggable"
    assert_not indicators(:unloaded).loggable?, "value_min nil (no data) is not loggable"
  end

  test "display_name falls back to the DB name when no i18n entry exists" do
    assert_equal "Catalogued but unloaded", indicators(:unloaded).display_name
  end

  test "code uniqueness is validated" do
    dup = Indicator.new(code: indicators(:gdp).code, name: "Dup", source: "X")
    assert_not dup.valid?
    assert dup.errors[:code].any?
  end

  test "with_observations returns only indicators that have observations" do
    codes = Indicator.with_observations.pluck(:code)
    assert_includes codes, "NY.GDP.PCAP.KD"
    assert_includes codes, "POLITY5"
    assert_not_includes codes, "TEST.NODATA"
  end
end
