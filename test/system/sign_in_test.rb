require "application_system_test_case"

# The sign-in page: the arena backdrop, and a form whose messages never move it.
class SignInTest < ApplicationSystemTestCase
  # The card's layout box (offsets ignore its entrance and shake transforms) and the page height.
  def card
    page.evaluate_script("(() => { const c = document.querySelector('.auth-card'); " \
                         "return [c.offsetTop, c.offsetHeight, document.body.scrollHeight] })()")
  end

  def canvas_frame
    page.evaluate_script("document.querySelector('#sign-in-arena canvas').toDataURL()")
  end

  test "a wrong password marks the form in place: nothing on the page moves" do
    visit login_path
    before = card

    fill_in "email", with: users(:admin).email
    fill_in "password", with: "wrong"
    click_on "Sign in"

    assert_selector "#login-message[data-tone=error]", text: "Wrong email or password. Try again."
    assert_field "email", with: users(:admin).email
    assert_equal "password", page.evaluate_script("document.activeElement.id"), "ready to type the password again"
    assert_equal before, card

    fill_in "password", with: "x"
    assert_selector "#login-message:empty", visible: :all
    assert_no_selector "[aria-invalid]"
    assert_equal before, card
  end

  test "the password can be shown and hidden" do
    visit login_path
    fill_in "password", with: "secret"

    find("button[aria-label='Show password']").click
    assert_selector "input#password[type=text]"
    assert_selector "button[aria-pressed=true][aria-label='Hide password']"

    find("button[aria-label='Hide password']").click
    assert_selector "input#password[type=password]"
  end

  test "the crowd does the wave, and holds still for people who prefer less motion" do
    visit login_path
    first = canvas_frame
    sleep 0.4
    assert_not_equal first, canvas_frame, "the arena animates"

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    visit login_path
    still = canvas_frame
    sleep 0.4
    assert_equal still, canvas_frame, "one still frame under reduced motion"
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  test "a message from another page floats in without moving the form" do
    visit login_path
    plain = card

    sign_in_via_form
    within("[data-shell=sidebar]") { click_on "Log out" }

    assert_selector ".auth-toast[role=status]", text: "Logged out successfully"
    assert_equal plain, card
  end
end
