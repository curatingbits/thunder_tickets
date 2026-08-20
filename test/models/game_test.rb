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
