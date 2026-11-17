require "test_helper"

# Golden tests on three real events from Kate's 2026-11-16 scrape:
# Hawks 11/18 (typical), Kings 12/16 (row DD listed, courtside asks,
# Standard Admission seats), Knicks 2/7 (pricey, no near-DD listings).
class Market::ScanIngestTest < ActiveSupport::TestCase
  CAPTURED = Time.zone.local(2026, 11, 16, 10, 2)

  setup do
    travel_to Time.zone.local(2026, 11, 16, 12)
    @season = seasons(:current)
    file = JSON.parse(file_fixture("tm_scrape_sample.json").read)
    @payloads = Market::ScrapeFile.payloads(file, captured_at: CAPTURED).index_by { |p| p[:event_date] }
    @games = @payloads.keys.sort.each_with_index.to_h do |date, i|
      [ date, @season.games.create!(game_number: 101 + i, game_date: Date.iso8601(date), opponent: teams(:rockets),
                                    cost_per_ticket: 162.52, parking_cost: 8.70, game_type: "regular") ]
    end
    @run, = ImportRun.start!(kind: "market_research", source: "ticketmaster_browser", key: "tm-test", client_id: "client-a")
  end

  def ingest(date, run: @run, payload: @payloads.fetch(date))
    Market::ScanIngest.new(run: run, game: @games.fetch(date), payload: payload).call
  end

  test "a typical game two days out: fee confirmed, competitive price" do
    snapshot = ingest("2026-11-18").snapshot

    assert_equal 2, snapshot.days_to_game
    assert snapshot.fee_verified
    assert_equal BigDecimal("1.215"), snapshot.buyer_fee_multiplier
    assert_equal 25, snapshot.captured_count
    assert_equal 25, snapshot.observations.count
    assert_equal 0, snapshot.tier1_count
    assert_operator snapshot.tier2_count, :>=, 1
    assert_equal "competitive", snapshot.recommended_strategy
    assert_equal (snapshot.competitive_price / BigDecimal("1.215")).floor, snapshot.recommended_list_price
    assert_operator snapshot.market_value, :>, snapshot.section_median
    assert_operator snapshot.competitive_price, :<=, snapshot.market_value
    assert_operator snapshot.market_value, :<=, snapshot.premium_price
    assert_equal "needs_verification", snapshot.assessment
    assert snapshot.rationale.first.include?("2 days out")
  end

  test "row DD, courtside and Standard Admission seats are each handled" do
    snapshot = ingest("2026-12-16").snapshot
    excluded = snapshot.observations.reject(&:kept?).group_by(&:excluded_reason).transform_values(&:count)

    assert_equal 1, snapshot.tier1_count
    assert_equal 2, excluded["courtside"], "101 FL2 $1,093.50 and FL3 $1,154.25"
    assert_equal 5, excluded["primary"]
    assert_equal BigDecimal("146.95"), snapshot.primary_min_price
    assert_equal "premium", snapshot.recommended_strategy
  end

  test "a pricey game with no near-DD listings is capped at the section's top ask, with low confidence" do
    snapshot = ingest("2027-02-07").snapshot

    assert_equal 0, snapshot.tier1_count + snapshot.tier2_count
    assert_equal snapshot.section_max, snapshot.market_value
    assert_equal "Low", snapshot.confidence_label
    assert snapshot.observations.any? { |o| o.row == "FL2" && o.excluded_reason == "courtside" }
  end

  test "replaying a scan returns the stored snapshot; a different scan is refused" do
    first = ingest("2026-11-18")
    replay = ingest("2026-11-18")

    assert replay.replayed
    assert_equal first.snapshot, replay.snapshot
    assert_equal 1, MarketSnapshot.count

    changed = @payloads["2026-11-18"].deep_dup
    changed[:listings].first[:price] += 1
    assert_raises(Market::ScanIngest::Conflict) { ingest("2026-11-18", payload: changed) }
  end

  test "a scan of the wrong night is refused" do
    payload = @payloads["2026-11-18"].merge(event_date: "2026-11-19")
    assert_raises(Market::ScanIngest::Invalid) { ingest("2026-11-18", payload: payload) }
  end

  test "bad listings are refused before anything is written" do
    payload = @payloads["2026-11-18"].deep_dup
    payload[:listings] << { section: "101", row: "EE", price: "free" }

    assert_raises(Market::ScanIngest::Invalid) { ingest("2026-11-18", payload: payload) }
    assert_equal 0, MarketSnapshot.count
  end

  test "ingest records the event; on its own it never touches sales or listings" do
    assert_no_difference [ -> { Ticket.count }, -> { Listing.count }, -> { ListingEvent.count } ] do
      ingest("2026-11-18")
    end
    game = @games["2026-11-18"].reload
    assert_equal "0C00650CB5337461", game.ticketmaster_event_id
    assert_match %r{ticketmaster.com/.+/event/0C00650CB5337461}, game.ticketmaster_url
  end

  test "a later scan links to the earlier one and reports the change" do
    ingest("2026-12-16")
    @run.finish!("completed")

    travel 5.days
    later_run, = ImportRun.start!(kind: "market_research", source: "ticketmaster_browser", key: "tm-test-2", client_id: "client-a")
    pricier = @payloads["2026-12-16"].deep_dup
    pricier[:captured_at] = Time.current.iso8601
    pricier[:listings].each { |l| l[:price] = (l[:price] * 1.1).round(2) }
    snapshot = ingest("2026-12-16", run: later_run, payload: pricier).snapshot

    assert snapshot.previous_snapshot.present?
    assert_in_delta 10, snapshot.market_value_change_pct, 1.5
  end

  test "our own verified listing is recognized in the market and assessed" do
    game = @games["2026-12-16"]
    # Row DD was listed at $151.88 all-in, i.e. $125 list.
    game.listings.create!(seat_numbers: [ 1, 2, 3 ], platform: "ticketmaster", ask_price: 125, verified_at: Time.current)

    snapshot = ingest("2026-12-16").snapshot

    assert snapshot.observed_our_listing
    assert_equal 0, snapshot.tier1_count
    assert_equal BigDecimal("151.88"), snapshot.our_all_in
    assert_includes %w[underpriced competitive], snapshot.assessment
  end
end
