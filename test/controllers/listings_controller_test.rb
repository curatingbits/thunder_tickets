require "test_helper"

class ListingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in
    @game = games(:current_future)
  end

  def create_listing(price: 210)
    post game_listings_path(@game), params: { listing: { kind: "listing", seat_numbers: [ "", "1", "2", "3" ],
                                                          platform: "ticketmaster", ask_price: price,
                                                          ask_price_basis: "seller_list", account_user_id: @user.id } }
    @game.listings.last
  end

  test "requires login" do
    delete logout_path
    get new_game_listing_path(@game)
    assert_redirected_to login_path
  end

  test "the new form offers the open seats" do
    @game.tickets.create!(seat_number: 3, sale_price: 150)
    get new_game_listing_path(@game)

    assert_response :success
    assert_select "input[type=checkbox][name='listing[seat_numbers][]']", count: 2
  end

  test "recording a listing counts as verified and logs the decision" do
    listing = create_listing

    assert_redirected_to game_path(@game)
    assert_equal [ 1, 2, 3 ], listing.seat_numbers
    assert_equal @user, listing.verified_by
    assert listing.verified_fresh?
    event = listing.events.sole
    assert_equal [ "listed", BigDecimal("210"), @user ], [ event.action, event.price_after, event.user ]
    assert_equal :listed, @game.reload.listing_status.status
  end

  test "an invalid listing re-renders with the error" do
    post game_listings_path(@game), params: { listing: { kind: "listing", seat_numbers: [ "" ], platform: "ticketmaster", ask_price: 210 } }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /pick at least one seat/
  end

  test "changing the price logs before and after" do
    listing = create_listing

    patch game_listing_path(@game, listing), params: { listing: { ask_price: 189 } }

    assert_redirected_to game_path(@game)
    event = listing.events.recent_first.first
    assert_equal [ "price_changed", BigDecimal("210"), BigDecimal("189") ], [ event.action, event.price_before, event.price_after ]
  end

  test "still listed refreshes the verification" do
    listing = create_listing
    listing.update_columns(verified_at: 10.days.ago)
    assert_equal :needs_verification, @game.reload.listing_status.status

    post verify_game_listing_path(@game, listing)

    assert listing.reload.verified_fresh?
    assert_equal :listed, @game.reload.listing_status.status
  end

  test "taking a listing down ends it and confirms the seats are unlisted" do
    listing = create_listing

    post close_game_listing_path(@game, listing)

    assert_equal [ "ended", "delisted" ], [ listing.reload.status, listing.end_reason ]
    assert_equal :not_listed, @game.reload.listing_status.status
  end

  test "not listed ends any recorded listing and records the confirmation" do
    listing = create_listing

    post verify_unlisted_game_listings_path(@game)

    assert_equal "ended", listing.reload.status
    assert_equal :not_listed, @game.reload.listing_status.status
    assert_equal "verified_unlisted", @game.listing_events.recent_first.first.action
  end
end
