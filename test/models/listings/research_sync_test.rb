require "test_helper"

class Listings::ResearchSyncTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.local(2026, 11, 16, 20)
    @game = seasons(:current).games.create!(game_number: 990, game_date: Date.new(2026, 11, 20), opponent: teams(:rockets),
                                            cost_per_ticket: 150, parking_cost: 8.7, game_type: "regular")
    @runs = 0
  end

  NEARBY = [ %w[101 K 145.80], %w[101 S 157.95], %w[102 L 151.88], %w[101 GG 181.04], %w[101 EE 303.75],
             %w[120 DD 235.71], %w[101 AA 250.00], %w[102 JJ 170.10] ].freeze

  # One research scan of the game, with these extra rows in our row (DD).
  def scan(ours: [], scroll_complete: true, captured_at: Time.current, sync: true)
    rows = NEARBY + ours.map { |price| [ "101", "DD", price.to_s ] }
    payload = { event_date: "2026-11-20", captured_at: captured_at.iso8601, scroll_complete: scroll_complete,
                listings: rows.each_with_index.map { |(sec, row, price), i| { position: i + 1, section: sec, row: row, price: price.to_f } } }
    run, = ImportRun.start!(kind: "market_research", source: "ticketmaster_browser", key: "r-#{@runs += 1}", client_id: "c")
    Market::ScanIngest.new(run: run, game: @game, payload: payload, sync_listings: sync).call.tap { run.finish!("completed") }
  end

  def status = @game.reload.listing_status

  test "our row on Ticketmaster: the open seats are recorded as listed at that price" do
    result = scan(ours: [ 194.40 ])

    assert_equal [ "listed", 194.4, [ 1, 2, 3 ] ], [ result.our_listing.outcome, result.our_listing.price, result.our_listing.seats ]
    listing = @game.listings.sole
    assert_equal [ "ticketmaster", BigDecimal("194.4"), "buyer_all_in" ], [ listing.platform, listing.ask_price, listing.ask_price_basis ]
    assert_equal :listed, status.status
    event = ListingEvent.sole
    assert_equal [ "listed", result.snapshot, nil ], [ event.action, event.market_snapshot, event.user ]
    assert result.snapshot.observed_our_listing, "our own listing isn't a comparable for itself"
    assert_equal BigDecimal("194.4"), result.snapshot.our_all_in
  end

  test "later scans confirm the price or record the change" do
    scan(ours: [ 194.40 ])
    assert_equal "confirmed", scan(ours: [ 194.40 ]).our_listing.outcome

    repriced = scan(ours: [ 182.25 ])
    assert_equal "repriced", repriced.our_listing.outcome
    assert_equal BigDecimal("182.25"), @game.listings.sole.ask_price
    change = ListingEvent.where(action: "price_changed").sole
    assert_equal [ BigDecimal("194.4"), BigDecimal("182.25") ], [ change.price_before, change.price_after ]
    assert_equal %w[listed verified price_changed], ListingEvent.order(:id).pluck(:action)
  end

  test "a listing someone recorded at its list price is compared all-in" do
    @game.listings.create!(seat_numbers: [ 1, 2, 3 ], platform: "ticketmaster", ask_price: 160, verified_at: 3.days.ago)
    assert_equal "confirmed", scan(ours: [ 194.40 ]).our_listing.outcome
    assert_equal "seller_list", @game.listings.sole.ask_price_basis
  end

  test "nothing in our row after a complete read: not listed, and the Ticketmaster listing ends" do
    scan(ours: [ 194.40 ])
    result = scan

    assert_equal "not_listed", result.our_listing.outcome
    assert_equal [ "ended", "delisted" ], @game.listings.sole.slice(:status, :end_reason).values
    assert_equal %w[listed ended verified_unlisted], ListingEvent.order(:id).pluck(:action)
    assert_equal :not_listed, status.status
  end

  test "a read that didn't finish can't say we're not listed" do
    scan(ours: [ 194.40 ])
    assert_equal "incomplete", scan(scroll_complete: false).our_listing.outcome
    assert_equal "active", @game.listings.sole.status
  end

  test "two prices in our row: it doesn't guess which is ours" do
    result = scan(ours: [ 194.40, 230.85 ])
    assert_equal [ "unclear", [ 194.4, 230.85 ] ], [ result.our_listing.outcome, result.our_listing.prices ]
    assert_empty @game.listings
  end

  test "only open seats are listed; holds and other platforms are left alone" do
    @game.tickets.create!(seat_number: 1, sale_price: 200)
    @game.listings.create!(kind: "hold", seat_numbers: [ 2 ], verified_at: Time.current)
    assert_equal [ 3 ], scan(ours: [ 194.40 ]).our_listing.seats

    other = seasons(:current).games.create!(game_number: 991, game_date: Date.new(2026, 11, 20), opponent: teams(:clippers),
                                             cost_per_ticket: 150, parking_cost: 8.7, game_type: "regular")
    other.listings.create!(seat_numbers: [ 1, 2, 3 ], platform: "stubhub", ask_price: 180, verified_at: Time.current)
    @game = other
    assert_equal "nothing_to_sell", scan.our_listing.outcome
    assert_equal "active", other.listings.sole.status
  end

  test "pasted, backfilled or old scans never touch listings" do
    assert_no_difference [ -> { Listing.count }, -> { ListingEvent.count } ] do
      assert_nil scan(ours: [ 194.40 ], sync: false).our_listing
      assert_nil scan(ours: [ 194.40 ], captured_at: 3.days.ago).our_listing
    end
  end
end
