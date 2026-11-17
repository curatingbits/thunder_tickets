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

  def snapshot_for(game, market:, captured_at: @now - 1.day, change: nil, status: "completed")
    run = ImportRun.create!(kind: "market_research", source: "ticketmaster_browser", key: "r-#{game.id}-#{captured_at.to_i}",
                            status: status, started_at: captured_at)
    MarketSnapshot.create!(import_run: run, game: game, captured_at: captured_at, days_to_game: game.days_until(captured_at.to_date),
                           payload_digest: SecureRandom.hex, engine_version: "1", buyer_fee_multiplier: 1.215, fee_verified: true,
                           market_value: market, competitive_price: market * 0.9, premium_price: market * 1.1,
                           recommended_strategy: "market", recommended_list_price: (market / 1.215).round,
                           confidence: 80, market_value_change_pct: change, section_count: 8,
                           confidence_breakdown: { "depth" => 40, "proximity" => 15, "consistency" => 10, "anchor" => 10, "coverage" => 10 })
  end

  test "a confirmed listing well above market within two weeks needs repricing" do
    game = game_on(@today + 10)
    game.listings.create!(seat_numbers: [ 1, 2, 3 ], platform: "ticketmaster", ask_price: 300, verified_at: @now - 1.day)
    snapshot_for(game, market: 250)

    item = feed_items(:reprice).sole
    assert_equal [ game, "overpriced", 2 ], [ item.game, item.assessment, item.priority ]
  end

  test "a falling market is flagged" do
    game = game_on(@today + 12)
    snapshot_for(game, market: 200, change: -14)

    assert_equal [ game ], feed_items(:market_drop).map(&:game)
  end

  test "old market data and a blocked run are season-wide items" do
    game = game_on(@today + 10)
    snapshot_for(game, market: 200, captured_at: @now - 10.days)
    assert_equal 1, feed_items(:research_stale).size

    ImportRun.create!(kind: "market_research", source: "ticketmaster_browser", key: "blocked", status: "blocked",
                      started_at: @now - 2.hours)
    blocked = feed_items(:research_blocked).sole
    assert_nil blocked.game
    assert_equal :research_blocked, feed_items.first.kind
  end

  test "no season, no items" do
    assert_empty Attention::Feed.new(nil).items
  end
end
