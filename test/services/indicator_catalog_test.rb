require "test_helper"

class IndicatorCatalogTest < ActiveSupport::TestCase
  test "entries are the with-observations active universe" do
    codes = IndicatorCatalog.entries.map { |e| e[:code] }
    assert_includes codes, "NY.GDP.PCAP.KD"
    assert_includes codes, "POLITY5"
    assert_not_includes codes, "TEST.NODATA"   # no observations -> excluded
  end

  test "include_loggable adds the loggable flag per entry" do
    by_code = IndicatorCatalog.entries(include_loggable: true).index_by { |e| e[:code] }
    assert by_code["NY.GDP.PCAP.KD"][:loggable]
    assert_not by_code["POLITY5"][:loggable]
    assert_nil IndicatorCatalog.entries.first[:loggable]   # omitted without the flag
  end

  test "taxonomy degrades gracefully on nil fields" do
    # The fixtures carry no dimension / data_source, so IndicatorTaxonomy must fall back without raising.
    gdp = IndicatorCatalog.entries.find { |e| e[:code] == "NY.GDP.PCAP.KD" }
    assert_equal "other", gdp[:dziedzina]   # nil dimension -> "other"
    assert_equal "global", gdp[:scope]      # nil data_source code -> "global"
  end
end
