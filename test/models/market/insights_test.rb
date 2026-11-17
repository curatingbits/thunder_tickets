require "test_helper"

class Market::InsightsTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:current)
    @number = 500
  end

  def game(team, date)
    @season.games.create!(game_number: @number += 1, game_date: Date.iso8601(date), opponent: teams(team),
                          cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
  end

  # One research run: [game, market value, extra snapshot attributes].
  def scan(at, rows)
    captured_at = Time.zone.parse(at)
    run = ImportRun.create!(kind: "market_research", source: "ticketmaster_browser", key: "scan-#{captured_at.to_i}",
                            status: "completed", started_at: captured_at)
    rows.map do |game, value, extra|
      MarketSnapshot.create!({ import_run: run, game: game, captured_at: captured_at,
                               days_to_game: (game.game_date - captured_at.to_date).to_i, payload_digest: SecureRandom.hex,
                               engine_version: "1", buyer_fee_multiplier: 1.215, fee_verified: true, market_value: value,
                               competitive_price: value * 0.9, premium_price: value * 1.1, recommended_strategy: "market",
                               recommended_list_price: (value / 1.215).round, confidence: 80, section_count: 8,
                               tier1_count: 0, tier2_count: 2, tier3_count: 1 }.merge(extra || {}))
    end
  end

  def insights = Market::Insights.new(@season)

  setup do
    @fri = game(:rockets, "2026-12-04")
    @tue = game(:clippers, "2026-12-08")
    @sat = game(:mavericks, "2026-12-12")
    @wed = game(:nuggets, "2026-12-16")
  end

  test "nothing to say until three games have a market value" do
    scan("2026-11-16 08:00", [ [ @fri, 200 ], [ @tue, 300 ] ])
    assert_not insights.enough?

    scan("2026-11-17 08:00", [ [ @sat, 400 ] ])
    assert insights.enough?
  end

  test "opponents and weekends are compared with the typical game in the same scan" do
    scan("2026-11-16 08:00", [ [ @fri, 200 ], [ @tue, 300 ], [ @sat, 400 ], [ @wed, 250 ] ])

    assert_equal 275, insights.typical_value
    assert_equal [ [ "Dallas Mavericks", 45 ], [ "Los Angeles Clippers", 9 ], [ "Denver Nuggets", -9 ], [ "Houston Rockets", -27 ] ],
                 insights.by_opponent.map { |g| [ g.label, g.vs_typical_pct ] }
    weekend, weeknight = insights.by_day_of_week
    assert_equal [ "weekend", 2, 300, 9 ], [ weekend.key, weekend.games, weekend.median_value, weekend.vs_typical_pct ]
    assert_equal [ "weeknight", 2, 275, 0 ], [ weeknight.key, weeknight.games, weeknight.median_value, weeknight.vs_typical_pct ]
  end

  test "every scan counts toward how far out, and the latest scan is each game's value" do
    scan("2026-11-16 08:00", [ [ @fri, 200 ], [ @tue, 300 ], [ @sat, 400 ], [ @wed, 250 ] ])
    scan("2026-12-02 08:00", [ [ @fri, 260 ], [ @sat, 380 ] ])

    buckets = insights.by_days_out.index_by(&:key)
    assert_equal [ 1, -19 ], [ buckets["week"].games, buckets["week"].vs_typical_pct ]
    assert_equal [ 2, 2, -4 ], [ buckets["three_weeks"].games, buckets["three_weeks"].scans, buckets["three_weeks"].vs_typical_pct ]
    assert_equal [ 3, 9 ], [ buckets["eight_weeks"].games, buckets["eight_weeks"].vs_typical_pct ]
    assert_equal 280, insights.typical_value
    assert_equal 2, insights.scan_count
  end

  test "supply is listings seen per game in each scan" do
    scan("2026-11-16 08:00", [ [ @fri, 200 ], [ @tue, 300 ], [ @sat, 400 ] ])
    scan("2026-11-23 08:00", [ [ @fri, 210, { section_count: 10, tier2_count: 4 } ], [ @tue, 320, { section_count: 12 } ] ])

    assert_equal [ [ Date.new(2026, 11, 16), 3, 8.0, 3.0 ], [ Date.new(2026, 11, 23), 2, 11.0, 4.0 ] ],
                 insights.supply.map { |p| [ p.captured_on, p.games, p.listings_per_game, p.nearby_per_game ] }
  end

  test "sales are compared with the market list price in the scan before the sale" do
    scan("2026-11-16 08:00", [ [ @fri, 200 ], [ @tue, 300 ], [ @sat, 400 ] ])
    @fri.tickets.create!(seat_number: 1, sale_price: 160, list_price_at_sale: 180, sold_at: Time.zone.parse("2026-11-20 10:00"))
    @tue.tickets.create!(seat_number: 1, sale_price: 220, sold_at: Time.zone.parse("2026-11-20 10:00"))
    @sat.tickets.create!(seat_number: 1, sale_price: 300, list_price_at_sale: 330, sold_at: Time.zone.parse("2026-11-10 10:00"))

    sale = insights.sales_vs_market.sole
    assert_equal [ @fri, 164.61, 9 ], [ sale.ticket.game, sale.market_list, sale.vs_market_pct ]
    assert_equal 1, insights.uncompared_sales_count
  end

  test "price history is a game's scans, oldest first" do
    scan("2026-11-16 08:00", [ [ @fri, 200 ], [ @tue, 300 ] ])
    history = Market::PriceHistory.new(@fri)
    assert_not history.chartable?

    scan("2026-12-02 08:00", [ [ @fri, 260, { our_all_in: 285 } ] ])
    history = Market::PriceHistory.new(@fri)
    assert history.chartable?
    assert_equal [ { label: "Nov 16", days: 18, market: 200, low: 180, high: 220, list: 165, ours: nil },
                   { label: "Dec 2", days: 2, market: 260, low: 234, high: 286, list: 214, ours: 285 } ], history.chart_data
  end
end
