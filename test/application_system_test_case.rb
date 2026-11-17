require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Software WebGL (SwiftShader), so the 3D seat map draws without a GPU, as on CI.
  WEBGL = %w[--use-angle=swiftshader --enable-unsafe-swiftshader].freeze

  # CI's two-core runners are slower than a workstation, more so while the 3D
  # seat map draws in software: give Capybara's waits some room.
  Capybara.default_max_wait_time = 5

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    WEBGL.each { |flag| options.add_argument(flag) }
  end

  # Signs in through the real login form.
  def sign_in_via_form(user = users(:admin), password: "password")
    visit login_path
    fill_in "email", with: user.email
    fill_in "password", with: password
    click_on "Sign in"
    assert_text "Welcome back"
  end
end
