require "test_helper"

class IndicatorsControllerTest < ActionDispatch::IntegrationTest
  test "GET /indicators/coverage returns JSON for a known indicator" do
    get "/indicators/coverage", params: { code: "NY.GDP.PCAP.KD" }
    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "GET /indicators/coverage 404s an unknown indicator" do
    get "/indicators/coverage", params: { code: "NOPE.NOPE" }
    assert_response :not_found
  end
end
