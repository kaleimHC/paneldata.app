require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "GET / renders the map/config page" do
    get root_path
    assert_response :success
  end

  test "GET /?run=<completed> renders result-mode" do
    get root_path(run: analysis_runs(:completed).id)
    assert_response :success
  end

  test "GET /?run=<bogus> falls back to config-mode without error" do
    get root_path(run: 999_999)
    assert_response :success
  end

  test "GET /system-info renders" do
    get system_info_path
    assert_response :success
  end

  test "GET /upload renders" do
    get upload_page_path
    assert_response :success
  end

  test "GET /methodology renders" do
    get methodology_path
    assert_response :success
  end
end
