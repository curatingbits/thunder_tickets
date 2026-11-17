require "test_helper"

class Attention::FeedTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:current)
    @today = Date.new(2026, 11, 16)
    @now = Time.zone.local(2026, 11, 16, 12)
  end

  # Sales default to delivered so each test sees only the items it's about.
  def game_on(date, sold: 0, delivered: true, opponent: teams(:rockets))
    game = @season.games.create!(game_number: @season.games.maximum(:game_number).to_i + 1, game_date: date,
                                 opponent: opponent, cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
    1.upto(sold) do |seat|
      game.tickets.create!(seat_number: seat, sale_price: 150, transferred_at: (@now if delivered))
    end
    game
  end

  def feed_items(kind = nil)
    items = Attention::Feed.new(@season, today: @today, now: @now).items
    kind ? items.select { |i| i.kind == kind } : items
  end

  test "next week's games with seats to sell, most urgent first" do
    later = game_on(@today + 6)
    tomorrow = game_on(@today + 1, sold: 2)
    in_three = game_on(@today + 3)

    items = feed_items(:unsold_soon)

    assert_equal [ tomorrow, in_three, later ], items.map(&:game)
    assert_equal [ 1, 2, 3 ], items.map(&:priority)
    assert_equal [ 1, 3, 3 ], items.map(&:seats_open)
    assert_equal [ 1, 3, 6 ], items.map(&:days)
  end

  test "sold-out, past and far-off games aren't unsold items" do
    game_on(@today + 2, sold: 3)
    game_on(@today - 1)
    game_on(@today + 25)

    assert_empty feed_items
  end

  test "game day itself counts" do
    tonight = game_on(@today)

    assert_equal [ tonight ], feed_items(:unsold_soon).map(&:game)
  end

  test "sold tickets not yet delivered within three days come first" do
    game = game_on(@today + 2, sold: 3, delivered: false)
    game_on(@today + 4, sold: 3, delivered: false)

    items = feed_items
    assert_equal [ :transfer_pending ], items.map(&:kind)
    assert_equal game, items.first.game
    assert_equal 1, items.first.priority
  end

  test "held seats aren't seats to sell" do
    game = game_on(@today + 2, sold: 1)
    game.listings.create!(kind: "hold", seat_numbers: [ 2, 3 ], verified_at: @now)

    assert_empty feed_items
  end

  test "further out, unconfirmed listings and confirmed-unlisted seats get flagged" do
    unknown = game_on(@today + 10)
    confirmed = game_on(@today + 12)
    ListingEvent.create!(game: confirmed, action: "verified_unlisted", occurred_at: @now - 1.day)
    listed = game_on(@today + 14)
    listed.listings.create!(seat_numbers: [ 1, 2, 3 ], platform: "ticketmaster", ask_price: 210, verified_at: @now - 1.day)

    assert_equal [ unknown ], feed_items(:verify_listing).map(&:game)
    assert_equal [ confirmed ], feed_items(:not_listed).map(&:game)
    assert_empty feed_items.select { |i| i.game == listed }
  end

  test "no season, no items" do
    assert_empty Attention::Feed.new(nil).items
  end
end
