require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get login page" do
    get login_path
    assert_response :success
  end

  test "should log in with valid credentials" do
    post login_path, params: { email: users(:admin).email, password: "password" }
    assert_redirected_to root_path
  end

  test "should reject invalid credentials" do
    post login_path, params: { email: users(:admin).email, password: "wrong" }
    assert_response :unprocessable_entity
  end

  test "should log out" do
    sign_in
    delete logout_path
    assert_redirected_to login_path
  end
end
