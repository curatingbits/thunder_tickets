require "test_helper"

class GameTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:current)
  end

  def build_game(attrs = {})
    Game.new({
      season: @season,
      game_number: 99,
      game_date: Date.new(2026, 10, 7),
      opponent: teams(:nuggets),
      cost_per_ticket: 100,
      parking_cost: 10,
      game_type: "preseason"
    }.merge(attrs))
  end

  test "accepts preseason as a game type" do
    assert build_game.valid?
  end

  test "accepts the other known game types" do
    %w[regular playoff nba_cup].each do |type|
      assert build_game(game_type: type).valid?, "#{type} should be valid"
    end
  end

  test "rejects an unknown game type" do
    refute build_game(game_type: "exhibition").valid?
  end

  test "preseason? identifies preseason games" do
    assert build_game.preseason?
    refute build_game(game_type: "regular").preseason?
  end

  test "the preseason scope returns only preseason games" do
    game = build_game
    game.save!

    assert_includes @season.games.preseason, game
    assert @season.games.preseason.all?(&:preseason?)
    refute_includes @season.games.regular_season, game
  end

  test "preseason games cost the same as any other game" do
    game = build_game
    # (100 * 3 seats) + 10 parking
    assert_equal BigDecimal("310"), game.total_cost
  end

  # --- fully_sold ------------------------------------------------------

  test "fully_sold returns only games with every seat sold for their season" do
    sold = Game.fully_sold

    assert_includes sold, games(:past_regular)    # 2 of 2 (2-seat season)
    refute_includes sold, games(:past_playoff)    # 1 of 2
    refute_includes sold, games(:current_past)    # 2 of 3 — partial is not "fully sold"
    refute_includes sold, games(:current_future)  # 0 of 3
  end

  test "a game becomes fully sold when its last seat sells" do
    game = games(:current_past)
    game.tickets.create!(seat_number: 3, sale_price: 100)

    assert_includes Game.fully_sold, game
  end

  # --- break-even ------------------------------------------------------

  test "break-even price covers tickets and each seat's share of parking" do
    # current_past: (100 * 3) + 20 parking = 320 over 3 seats
    assert_in_delta 106.67, games(:current_past).break_even_price_per_ticket, 0.005
  end

  test "remaining seats must cover whatever cost is still outstanding" do
    game = games(:current_past) # cost 320, revenue 250, 1 seat left

    assert_equal 70, game.remaining_to_break_even
    assert_equal 70, game.break_even_price_for_remaining
  end

  test "once a game covers its cost there's no break-even price for the rest" do
    game = games(:current_past)
    game.tickets.find_by(seat_number: 1).update!(sale_price: 300) # revenue 420 > cost 320

    assert_equal 0, game.remaining_to_break_even
    assert_nil game.break_even_price_for_remaining
  end

  test "an unsold game spreads its whole cost over every seat" do
    game = games(:current_future) # cost 320, nothing sold

    assert_equal 320, game.remaining_to_break_even
    assert_in_delta 106.67, game.break_even_price_for_remaining, 0.005
  end

  # --- cup_round -------------------------------------------------------

  test "cup_round reads the round from a regular game in the Cup package" do
    game = build_game(game_type: "regular", playoff_round: "Group Play")
    assert_equal "Group Play", game.cup_round
  end

  test "cup_round reads the round from a standalone nba_cup game" do
    game = build_game(game_type: "nba_cup", playoff_round: "Quarterfinals")
    assert_equal "Quarterfinals", game.cup_round
  end

  test "cup_round is nil for ordinary and playoff games" do
    assert_nil build_game(game_type: "regular").cup_round
    assert_nil build_game(game_type: "preseason").cup_round
    assert_nil build_game(game_type: "playoff", playoff_round: "First Round").cup_round
  end
end
