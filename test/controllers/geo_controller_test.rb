require "test_helper"

class GeoControllerTest < ActionDispatch::IntegrationTest
  # A name that does not resolve to a file in the /srv geo cache must answer 404 (never 500, never a leak).
  # The route regex + File.basename defuse path traversal upstream, so the controller only ever sees a basename.
  test "GET /geo/:name returns 404 for a geojson that is not on disk" do
    get "/geo/no-such-borders-file.geojson"
    assert_response :not_found
  end

  test "GET /geo/:name with a basename-only name still 404s without leaking" do
    get "/geo/secret.geojson"
    assert_response :not_found
  end
end
