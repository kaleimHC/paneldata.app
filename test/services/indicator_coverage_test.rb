require "test_helper"

class IndicatorCoverageTest < ActiveSupport::TestCase
  test "runs RLE-encodes contiguous years into [from, to] spans" do
    assert_equal [], IndicatorCoverage.runs([])
    assert_equal [[2000, 2000]], IndicatorCoverage.runs([2000])
    assert_equal [[2000, 2002]], IndicatorCoverage.runs([2000, 2001, 2002])
    assert_equal [[1995, 1996], [2000, 2000]], IndicatorCoverage.runs([1995, 1996, 2000])
    assert_equal [[2000, 2002]], IndicatorCoverage.runs([2002, 2000, 2001, 2000]) # unsorted + duplicate
  end

  test "coerce_years handles the pg array string form and a ruby array" do
    assert_equal [2000, 2001], IndicatorCoverage.coerce_years("{2000,2001}")
    assert_equal [2000, 2001], IndicatorCoverage.coerce_years([2000, 2001])
  end

  test "for(indicator) returns per-country run-length year spans from observations" do
    cov = IndicatorCoverage.for(indicators(:gdp))
    assert_equal [[2000, 2002]], cov["POL"]
    assert_equal [[2000, 2002]], cov["DEU"]
    assert_equal [[2000, 2001]], cov["FRA"] # FRA has no GDP 2002
  end
end
