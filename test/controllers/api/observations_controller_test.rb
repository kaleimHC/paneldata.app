require "test_helper"

class Api::ObservationsControllerTest < ActionDispatch::IntegrationTest
  test "GET /api/observations returns country-only fill data and the year range" do
    get "/api/observations", params: { indicator: "NY.GDP.PCAP.KD", year: 2000 }
    assert_response :success
    body = JSON.parse(response.body)

    assert_equal "NY.GDP.PCAP.KD", body["indicator"]["code"]
    assert_equal 2000, body["year"]
    # GDP 2000 for the three country fixtures (all entity_type=country).
    assert_equal({ "POL" => 10000.0, "DEU" => 30000.0, "FRA" => 28000.0 }, body["observations"])
    assert_equal [2000, 2002], body["year_range"]
  end

  test "GET /api/observations for an indicator with no observations returns empty data and a [nil, nil] range" do
    get "/api/observations", params: { indicator: "TEST.NODATA", year: 2000 }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal({}, body["observations"])
    assert_equal [nil, nil], body["year_range"]
  end
end
