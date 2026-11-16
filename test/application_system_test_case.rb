require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Signs in through the real login form.
  def sign_in_via_form(user = users(:admin), password: "password")
    visit login_path
    fill_in "email", with: user.email
    fill_in "password", with: password
    click_on "Sign in"
    assert_text "Welcome back"
  end
end
