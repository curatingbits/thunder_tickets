require "test_helper"

class Reports::WeeklyTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:current)
    travel_to Time.zone.local(2026, 11, 18, 12)
    @game = @season.games.create!(game_number: 600, game_date: Date.new(2026, 11, 25), opponent: teams(:rockets),
                                  cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
    @later = @season.games.create!(game_number: 601, game_date: Date.new(2026, 12, 20), opponent: teams(:clippers),
                                   cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
  end

  def report(week = Date.new(2026, 11, 18)) = Reports::Weekly.new(@season, week: week, now: Time.current)

  def snapshot(game, at, change)
    run = ImportRun.find_or_create_by!(key: "run-#{at.to_i}") do |r|
      r.assign_attributes(kind: "market_research", source: "ticketmaster_browser", status: "completed", started_at: at)
    end
    MarketSnapshot.create!(import_run: run, game: game, captured_at: at, days_to_game: (game.game_date - at.to_date).to_i,
                           payload_digest: SecureRandom.hex, engine_version: "1", buyer_fee_multiplier: 1.215, fee_verified: true,
                           market_value: 250, competitive_price: 225, premium_price: 275, recommended_strategy: "market",
                           recommended_list_price: 206, confidence: 80, market_value_change_pct: change)
  end

  def payment(id, on, status: "matched")
    PartnerPayment.create!(source: "manual", external_id: id, occurred_on: on, amount_cents: 5_000, direction: "incoming",
                           counterparty: "Pat Partner", memo: "Thunder", category: "settlement", status: status)
  end

  test "a week runs Monday to Sunday, Central time" do
    r = report
    assert_equal [ Date.new(2026, 11, 16), Date.new(2026, 11, 22) ], [ r.week_start, r.week_end ]
    assert r.current?
    assert_nil r.next_week

    @game.tickets.create!(seat_number: 1, sale_price: 200, sold_at: Time.zone.local(2026, 11, 22, 23, 30))
    @game.tickets.create!(seat_number: 2, sale_price: 210, sold_at: Time.zone.local(2026, 11, 23, 0, 30))
    @game.tickets.create!(seat_number: 3, sale_price: 220, sold_at: Time.zone.local(2026, 11, 15, 22, 0))

    line = report.sales.sole
    assert_equal [ @game, 1, 200.0 ], [ line.game, line.tickets.size, line.payout ]
  end

  test "research, market moves, listing decisions and payments come from that week only" do
    snapshot(@game, Time.zone.local(2026, 11, 16, 6, 30), -14)
    snapshot(@later, Time.zone.local(2026, 11, 16, 6, 30), 3)
    snapshot(@later, Time.zone.local(2026, 11, 9, 6, 30), -30)
    ListingEvent.create!(game: @game, action: "listed", price_after: 210, occurred_at: Time.zone.local(2026, 11, 17, 9))
    ListingEvent.create!(game: @game, action: "verified", occurred_at: Time.zone.local(2026, 11, 12, 9))
    payment("in-week", Date.new(2026, 11, 17))
    payment("ignored", Date.new(2026, 11, 17), status: "ignored")
    payment("last-week", Date.new(2026, 11, 10))

    r = report
    assert_equal 1, r.research_runs.size
    assert_equal [ @game ], r.market_moves.map(&:game)
    assert_equal(-5.5, r.median_change_pct)
    assert_equal [ "listed" ], r.listing_events.map(&:action)
    assert_equal [ "in-week" ], r.payments.map(&:external_id)
    assert_not r.quiet?
  end

  test "the current week adds what's coming up and what needs attention; past weeks don't" do
    current = report
    assert_equal [ @game ], current.upcoming.map(&:game)
    assert_includes current.attention.map(&:kind), :unsold_soon

    past = report(Date.new(2026, 11, 9))
    assert_not past.current?
    assert_equal Date.new(2026, 11, 16), past.next_week
    assert_empty past.upcoming
    assert_empty past.attention
    assert past.quiet?
  end

  test "the API version carries the same week" do
    snapshot(@game, Time.zone.local(2026, 11, 16, 6, 30), -14)
    json = Reports::WeeklyJson.call(report)

    assert_equal [ "2026-11-16", "2026-11-22", true ], json.values_at(:week_start, :week_end, :current)
    assert_equal [ -14.0 ], json[:market][:moves].map { |m| m[:change_pct] }
    assert_equal [ @game.id ], json[:upcoming].map { |u| u[:game_id] }
    assert json[:attention].all? { |a| a[:title].present? }
  end
end
