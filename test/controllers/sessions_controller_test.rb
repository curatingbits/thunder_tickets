require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get login page" do
    get login_path
    assert_response :success
    assert_select "h1 svg[role=img][aria-label=?]", "MADR Tickets", 1, "the stacked logo heads the page"
  end

  test "should log in with valid credentials" do
    post login_path, params: { email: users(:admin).email, password: "password" }
    assert_redirected_to root_path
  end

  test "should reject invalid credentials" do
    post login_path, params: { email: users(:admin).email, password: "wrong" }
    assert_response :unprocessable_entity
  end

  test "a deactivated user can't log in" do
    users(:admin).update!(active: false)

    post login_path, params: { email: users(:admin).email, password: "password" }

    assert_response :unprocessable_entity
    assert_equal "Invalid email or password", flash[:alert]
  end

  test "deactivating a user ends their open session" do
    sign_in
    get root_path
    assert_response :success

    users(:admin).update!(active: false)

    get root_path
    assert_redirected_to login_path
  end

  test "should log out" do
    sign_in
    delete logout_path
    assert_redirected_to login_path

    get root_path
    assert_redirected_to login_path
  end

  test "the login cookie lasts a year, so closing the browser or the app doesn't end it" do
    sign_in

    cookie = Array(response.headers["set-cookie"]).join("\n")[/^_thunder_tickets_session=.*$/]
    assert_in_delta 1.year.from_now, Time.httpdate(cookie[/expires=([^;]+)/i, 1]), 1.minute
  end

  test "a login ends a year after sign-in, however often it's used" do
    sign_in
    travel 200.days
    get root_path
    assert_response :success

    travel 170.days
    get root_path
    assert_redirected_to login_path
  end

  test "a password reset ends logins made with the old password" do
    sign_in
    users(:admin).reset_password("a-new-password", "a-new-password")

    get root_path
    assert_redirected_to login_path
  end

  test "accepting an invitation logs the new user in" do
    user = User.create!(email: "new@example.com", name: "New", password: SecureRandom.hex(8)).tap(&:generate_invitation_token!)

    patch accept_invitation_path(user.invitation_token), params: { user: { password: "secret123", password_confirmation: "secret123" } }
    follow_redirect!

    assert_response :success
  end
end
