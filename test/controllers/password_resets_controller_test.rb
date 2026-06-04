require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_password_reset_path
    assert_response :success
  end

  test "create redirects to login (known email)" do
    post password_resets_path, params: { email: users(:admin).email }
    assert_redirected_to login_path
  end

  test "create redirects to login (unknown email, no enumeration)" do
    post password_resets_path, params: { email: "nobody@example.com" }
    assert_redirected_to login_path
  end

  test "edit with an invalid token redirects to login" do
    get edit_password_reset_path("not-a-real-token")
    assert_redirected_to login_path
  end
end
