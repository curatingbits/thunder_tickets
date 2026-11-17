require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    @game = games(:current_past)
  end

  test "should get index" do
    get games_path
    assert_response :success
  end

  test "the Fully Sold filter excludes partially sold games" do
    # Current season: current_past is 2 of 3 sold, current_future 0 of 3.
    get games_path(filter: "sold")
    assert_response :success
    assert_select "p", text: "No games found"
  end

  test "the Fully Sold filter lists a game once every seat is sold" do
    @game.tickets.create!(seat_number: 3, sale_price: 100)

    get games_path(filter: "sold")
    assert_response :success
    assert_select "table.data-table tbody tr", count: 1
    assert_select "table.data-table tbody", text: /Dallas Mavericks/
  end

  test "should get new" do
    get new_game_path
    assert_response :success
  end

  test "should get show" do
    get game_path(@game)
    assert_response :success
  end

  test "should get edit" do
    get edit_game_path(@game)
    assert_response :success
  end
  test "the needs-attention filter shows next week's games with seats left" do
    sign_in
    soon = seasons(:current).games.create!(game_number: 90, game_date: Date.current + 2, opponent: teams(:rockets),
                                           cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
    sold_out = seasons(:current).games.create!(game_number: 91, game_date: Date.current + 3, opponent: teams(:clippers),
                                               cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
    3.times { |i| sold_out.tickets.create!(seat_number: i + 1, sale_price: 150) }

    get games_path(filter: "attention")

    assert_response :success
    assert_select "table.data-table tbody tr", count: 1
    assert_select "table.data-table tbody", text: /Houston Rockets/
    assert_select "a", text: "Needs attention"
  end
end
