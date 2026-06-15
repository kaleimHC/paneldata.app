require "test_helper"
require "csv"
require "tmpdir"

class PanelBuilderTest < ActiveSupport::TestCase
  # Fixtures: GDP + Polity for POL/DEU/FRA over 2000-2002, FRA missing GDP 2002.
  test "strict balance drops a country missing a year and counts the balanced ones" do
    Dir.mktmpdir do |dir|
      out = File.join(dir, "panel.csv")
      result = PanelBuilder.build(
        response_indicator: indicators(:gdp), predictor_indicator: indicators(:polity),
        start_year: 2000, end_year: 2002, out_path: out)

      assert_equal 2, result.n_countries, "FRA (missing GDP 2002) must be dropped, leaving POL and DEU"
      assert_equal 3, result.n_years
      assert_equal 6, result.rows, "2 balanced countries x 3 years"
      assert_equal out, result.csv_path

      rows = CSV.read(out, headers: true)
      assert_equal %w[iso3c year response predictor], rows.headers
      isos = rows.map { |r| r["iso3c"] }.uniq.sort
      assert_equal %w[DEU POL], isos
    end
  end

  test "build writes the response and predictor values for each balanced country-year" do
    Dir.mktmpdir do |dir|
      out = File.join(dir, "panel.csv")
      PanelBuilder.build(
        response_indicator: indicators(:gdp), predictor_indicator: indicators(:polity),
        start_year: 2000, end_year: 2002, out_path: out)
      row = CSV.read(out, headers: true).find { |r| r["iso3c"] == "POL" && r["year"] == "2000" }
      assert_in_delta 10000.0, row["response"].to_f, 0.001
      assert_in_delta 8.0, row["predictor"].to_f, 0.001
    end
  end
end
