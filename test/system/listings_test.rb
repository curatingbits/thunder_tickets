require "mobile_system_test_case"

class MobileListingsTest < MobileSystemTestCase
  setup do
    @game = games(:current_future)
    sign_in_via_form
  end

  test "list seats, change the price, confirm it's still up" do
    visit game_path(@game)
    within("[data-listing-card]") do
      assert_selector "[data-listing-status='needs_verification']"
      click_on "List seats"
    end

    assert_selector "h1", text: "Record a listing"
    assert_checked_field "Seat 1"
    uncheck "Seat 3"
    fill_in "Asking price per ticket", with: "215"
    click_on "Record listing"

    assert_text "Listing recorded at $215.00."
    within("[data-listing-card]") do
      assert_selector "[data-listing-status='needs_verification']"
      assert_text "Seats 1 and 2 at $215.00"
      click_on "Change price"
    end

    fill_in "Asking price per ticket", with: "199"
    click_on "Save"
    assert_text "Price changed to $199.00."

    within("[data-listing-card]") do
      assert_text "Price $215.00 → $199.00"
      click_on "Hold seats"
    end
    check "Seat 3"
    click_on "Hold seats"

    within("[data-listing-card]") do
      assert_selector "[data-listing-status='listed']"
      assert_text "Seat 3 held"
    end
  end
end
