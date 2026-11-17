require "test_helper"

class Attention::FeedTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:current)
    @today = Date.new(2026, 11, 16)
  end

  def game_on(date, sold: 0, opponent: teams(:rockets))
    game = @season.games.create!(game_number: @season.games.maximum(:game_number).to_i + 1, game_date: date,
                                 opponent: opponent, cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
    1.upto(sold) { |seat| game.tickets.create!(seat_number: seat, sale_price: 150) }
    game
  end

  test "lists next week's games that still have seats to sell, most urgent first" do
    later = game_on(@today + 6)
    tomorrow = game_on(@today + 1, sold: 2)
    in_three = game_on(@today + 3)

    items = Attention::Feed.new(@season, today: @today).items

    assert_equal [ tomorrow, in_three, later ], items.map(&:game)
    assert_equal [ 1, 2, 3 ], items.map(&:priority)
    assert_equal [ 1, 3, 3 ], items.map(&:seats_open)
    assert_equal [ 1, 3, 6 ], items.map(&:days)
  end

  test "leaves out sold-out, past and later games" do
    game_on(@today + 2, sold: 3)
    game_on(@today - 1)
    game_on(@today + 8)

    assert_empty Attention::Feed.new(@season, today: @today).items
  end

  test "game day itself counts" do
    tonight = game_on(@today)

    assert_equal [ tonight ], Attention::Feed.new(@season, today: @today).items.map(&:game)
  end

  test "no season, no items" do
    assert_empty Attention::Feed.new(nil).items
  end
end
