require "test_helper"

class MoreControllerTest < ActionDispatch::IntegrationTest
  test "requires login" do
    get more_path
    assert_redirected_to login_path
  end

  test "lists the pages without a tab of their own" do
    sign_in
    get more_path

    assert_response :success
    assert_select "h1", "More"
    assert_select "main a[href=?]", buyers_path
    assert_select "main a[href=?]", seasons_path
    assert_select "main a[href=?]", users_path
    assert_select "main a[href=?]", settings_path
    assert_select "main form[action=?]", logout_path
  end
end
