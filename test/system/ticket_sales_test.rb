require "application_system_test_case"

class TicketSalesTest < ApplicationSystemTestCase
  setup do
    @game = games(:current_past) # seats 1-2 sold, seat 3 open
    @ticket = tickets(:cur_past_1) # seat 1, $130

    visit login_path
    fill_in "email", with: users(:admin).email
    fill_in "password", with: "password"
    click_on "Sign in"
    assert_text "Welcome back"
  end

  test "the single and bulk sale tabs swap forms and highlight the active tab" do
    visit game_path(@game)

    single_tab = "[data-bulk-sale-target='singleTab']"
    bulk_tab = "[data-bulk-sale-target='bulkTab']"

    assert_selector "#{single_tab}.bg-accent"
    assert_selector "#{bulk_tab}.bg-surface-raised"
    assert_selector "[data-bulk-sale-target='singleForm']", visible: :visible
    assert_selector "[data-bulk-sale-target='bulkForm']", visible: :hidden

    find(bulk_tab).click

    assert_selector "#{bulk_tab}.bg-accent"
    assert_selector "#{single_tab}.bg-surface-raised"
    assert_no_selector "#{single_tab}.bg-accent"
    assert_selector "[data-bulk-sale-target='bulkForm']", visible: :visible
    assert_selector "[data-bulk-sale-target='singleForm']", visible: :hidden

    find(single_tab).click

    assert_selector "#{single_tab}.bg-accent"
    assert_no_selector "#{bulk_tab}.bg-accent"
    assert_selector "[data-bulk-sale-target='singleForm']", visible: :visible
  end

  test "editing a sale from the game page" do
    visit game_path(@game)
    find("a[href='#{edit_game_ticket_path(@game, @ticket)}']").click

    assert_selector "h1", text: "Edit Sale"
    fill_in "Sale Price", with: "180"
    select "3", from: "Seat"
    select "No buyer", from: "Buyer"
    click_on "Save Changes"

    assert_text "Sale updated."
    @ticket.reload
    assert_equal 180, @ticket.sale_price
    assert_equal 3, @ticket.seat_number
    assert_nil @ticket.buyer_id
  end
end
