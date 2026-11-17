require "test_helper"

class ListingReviewsControllerTest < ActionDispatch::IntegrationTest
  test "lists upcoming games that still have seats to sell" do
    sign_in
    sold_out = seasons(:current).games.create!(game_number: 95, game_date: Date.current + 5, opponent: teams(:rockets),
                                               cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
    3.times { |i| sold_out.tickets.create!(seat_number: i + 1, sale_price: 150) }

    get listing_review_path

    assert_response :success
    assert_select "[data-review-game='#{games(:current_future).id}']", count: 1
    assert_select "[data-review-game='#{sold_out.id}']", count: 0
    assert_select "[data-review-game='#{games(:current_past).id}']", count: 0
    assert_select "[data-listing-status='needs_verification']"
  end
end
