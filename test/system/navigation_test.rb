require "application_system_test_case"
require "mobile_system_test_case"

class DesktopNavigationTest < ApplicationSystemTestCase
  setup { sign_in_via_form }

  test "desktop uses the sidebar, not the phone tab bar" do
    assert_selector "[data-shell='sidebar']", visible: :visible
    assert_selector "[data-shell='bottom-nav']", visible: :hidden
    assert_selector "[data-shell='top-bar']", visible: :hidden
  end

  test "sidebar links mark the current page" do
    within("[data-shell='sidebar']") { click_on "Games" }

    assert_current_path games_path
    within("[data-shell='sidebar']") do
      assert_selector "a[aria-current='page']", text: "Games"
      assert_selector "a[aria-current='page']", count: 1
    end

    within("[data-shell='sidebar']") { click_on "Users" }
    assert_current_path users_path
    within("[data-shell='sidebar']") { assert_selector "a[aria-current='page']", text: "Users" }
  end

  test "a flash message can be dismissed" do
    assert_text "Welcome back"
    find("[aria-label='Dismiss message']").click
    assert_no_text "Welcome back"
  end
end

class MobileNavigationTest < MobileSystemTestCase
  setup { sign_in_via_form }

  test "phones get the top bar and bottom tab bar, not the sidebar" do
    assert_selector "[data-shell='bottom-nav']", visible: :visible
    assert_selector "[data-shell='top-bar']", visible: :visible
    assert_selector "[data-shell='sidebar']", visible: :hidden
    within("[data-shell='top-bar']") { assert_selector "[data-season-indicator='current']" }
  end

  test "tabs switch pages and mark the current one" do
    within("[data-shell='bottom-nav']") do
      assert_selector "a[aria-current='page']", text: "Home"
      click_on "Games"
    end

    assert_current_path games_path
    within("[data-shell='bottom-nav']") { assert_selector "a[aria-current='page']", text: "Games" }
  end

  test "More holds the remaining pages and stays current inside them" do
    within("[data-shell='bottom-nav']") { click_on "More" }

    assert_selector "h1", text: "More"
    within("[data-shell='bottom-nav']") { assert_selector "a[aria-current='page']", text: "More" }

    click_on "Settings"
    assert_current_path settings_path
    within("[data-shell='bottom-nav']") { assert_selector "a[aria-current='page']", text: "More" }
  end

  test "logging out from More returns to the login page" do
    within("[data-shell='bottom-nav']") { click_on "More" }
    click_on "Log out"

    assert_current_path login_path
    assert_no_selector "[data-shell='bottom-nav']"
  end

  test "page content clears the tab bar" do
    within("[data-shell='bottom-nav']") { click_on "Games" }

    padding = page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('main')).paddingBottom)")
    bar = page.evaluate_script("document.querySelector(\"[data-shell='bottom-nav']\").getBoundingClientRect().height")
    assert_operator padding, :>=, bar, "main's bottom padding (#{padding}px) should clear the tab bar (#{bar}px)"
  end
end

class MobileThemeTest < MobileSystemTestCase
  setup { sign_in_via_form }

  test "the theme choice applies at once and survives a reload" do
    assert_selector "html[data-theme='dark']", visible: :all

    within("[data-shell='bottom-nav']") { click_on "More" }
    click_on "Light"

    assert_selector "html[data-theme='light']", visible: :all
    assert_selector "button[aria-pressed='true']", text: "Light"
    canvas = page.evaluate_script("getComputedStyle(document.body).backgroundColor")
    assert_equal "rgb(238, 240, 245)", canvas

    visit root_path
    assert_selector "html[data-theme='light']", visible: :all

    within("[data-shell='bottom-nav']") { click_on "More" }
    click_on "Dark"
    assert_selector "html[data-theme='dark']", visible: :all
  end
end
