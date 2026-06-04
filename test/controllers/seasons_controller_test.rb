require "test_helper"

class SeasonsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in }

  test "should get index listing all seasons" do
    get seasons_path
    assert_response :success
    assert_select "h1", text: "Seasons"
    assert_match seasons(:current).year, response.body
    assert_match seasons(:past_season).year, response.body
  end

  test "index requires login" do
    delete logout_path
    get seasons_path
    assert_redirected_to login_path
  end

  test "should get settings edit" do
    get settings_path
    assert_response :success
  end
end
