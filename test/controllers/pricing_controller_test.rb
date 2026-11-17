require "test_helper"

class PricingControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 11, 16, 12)
    sign_in
    @game = seasons(:current).games.create!(game_number: 101, game_date: Date.new(2026, 11, 18), opponent: teams(:rockets),
                                            cost_per_ticket: 162.52, parking_cost: 8.70, game_type: "regular")
    payload = Market::ScrapeFile.payloads(JSON.parse(file_fixture("tm_scrape_sample.json").read), captured_at: Time.current)
                                .find { |p| p[:event_date] == "2026-11-18" }
    run = ImportRun.create!(kind: "market_research", source: "backfill", key: "t", status: "completed", started_at: Time.current)
    @snapshot = Market::ScanIngest.new(run: run, game: @game, payload: payload).call.snapshot
  end

  test "the board shows market value, the recommendation and what our seats are worth" do
    get pricing_path

    assert_response :success
    assert_select "h1", "Pricing"
    assert_select "[data-pricing-game='#{@game.id}']", minimum: 1
    assert_select "[data-pricing-tiles]", text: /What our unsold seats are worth/
    assert_select "[data-assessment='needs_verification']", minimum: 1
    assert_match "List $#{@snapshot.recommended_list_price.round}", response.body
  end

  test "the board opens on unsold games, and All adds the sold and transferred ones" do
    @game.tickets.create!(seat_number: 3, sale_price: 150)

    get pricing_path
    assert_select "[data-pricing-filter='unsold'][aria-current='page'][href=?]", pricing_path
    assert_select "[data-pricing-game='#{@game.id}']", { minimum: 1 }, "a partly sold game still has seats to price"

    @game.tickets.create!(seat_number: 1, sale_price: 150, transferred_at: Time.current)
    @game.tickets.create!(seat_number: 2, sale_price: 150, transferred_at: Time.current)

    get pricing_path
    assert_select "[data-pricing-game='#{@game.id}']", count: 0
    assert_select "[data-listing-status='sold'], [data-listing-status='transferred']", count: 0

    get pricing_path(filter: "all")
    assert_select "[data-pricing-filter='all'][aria-current='page']"
    assert_select "[data-pricing-filter='unsold'][aria-current]", count: 0
    assert_select "[data-pricing-game='#{@game.id}'] [data-listing-status='sold']", minimum: 1
  end

  test "each game with market data has a 3D button that opens its map page" do
    get pricing_path

    assert_select "a[data-seat-map-game-link='#{@game.id}'][href=?]", seat_map_path(game_id: @game.id), 2, "in the table and on the phone card"
    assert_select "a[href=?]", seat_map_path, text: "3D seat map →"
    assert_select "#seat-map", { count: 0 }, "the map has its own page"
  end

  test "the game page links to its seats on the map" do
    get game_path(@game)
    assert_select "a[data-seat-map-link='#{@game.id}'][href=?]", seat_map_path(game_id: @game.id)
  end

  test "filters narrow the board" do
    @game.listings.create!(seat_numbers: [ 1, 2, 3 ], platform: "ticketmaster", ask_price: 400, verified_at: Time.current)

    get pricing_path(filter: "overpriced")
    assert_select "[data-pricing-game='#{@game.id}']", minimum: 1
    assert_select "[data-assessment='overpriced']", minimum: 1

    get pricing_path(filter: "underpriced")
    assert_select "[data-pricing-game='#{@game.id}']", count: 0
  end

  test "the game page shows the market card with the listings read" do
    get game_path(@game)

    assert_select "[data-market-card]" do
      assert_select "[data-price='competitive']"
      assert_select "[data-price='market']"
      assert_select "[data-price='premium']"
      assert_select "summary", text: "All 25 listings read"
    end
  end

  test "pricing decisions record what the app recommended" do
    post game_listings_path(@game), params: { listing: { kind: "listing", seat_numbers: [ "1", "2", "3" ], platform: "ticketmaster",
                                                          ask_price: 230, ask_price_basis: "seller_list" } }

    event = @game.reload.listing_events.sole
    assert_equal @snapshot, event.market_snapshot
    assert_equal @snapshot.recommended_list_price, event.recommended_list_price
    follow_redirect!
    assert_match "app suggested $#{@snapshot.recommended_list_price.round}", response.body
  end

  test "the run log lists runs and their results" do
    get import_runs_path
    assert_select "a[href=?]", import_run_path(@snapshot.import_run)

    get import_run_path(@snapshot.import_run)
    assert_response :success
    assert_select "td", text: /Houston Rockets/
  end

  test "home shows the next three unsold games the way Pricing lists them" do
    game = ->(number, day) { seasons(:current).games.create!(game_number: number, game_date: Date.new(2026, 11, day), opponent: teams(:rockets),
                                                             cost_per_ticket: 162.52, parking_cost: 8.70, game_type: "regular") }
    sold_out = game.(102, 17)
    (1..3).each { |seat| sold_out.tickets.create!(seat_number: seat, sale_price: 150) }
    later = [ game.(103, 20), game.(104, 25), game.(105, 27) ]

    get root_path

    shown = css_select("[data-dashboard-section='next-unsold'] [data-pricing-game]").map { |e| e["data-pricing-game"].to_i }.uniq
    assert_equal [ @game.id, *later.first(2).map(&:id) ], shown, "soonest first, skipping the sold-out game"
    assert_select "[data-dashboard-section='next-unsold'] tr[data-pricing-game='#{@game.id}']", text: /List \$#{@snapshot.recommended_list_price.round}/
    assert_select "[data-dashboard-section='next-unsold'] a[data-seat-map-game-link='#{@game.id}']", 2, "the 3D button, in the table and on the phone card"
    assert_select "[data-dashboard-section='pricing']", text: /Our prices vs the market/
    assert_no_match "What our unsold seats are worth", response.body

    get pricing_path
    assert_equal shown, css_select("[data-pricing-game]").map { |e| e["data-pricing-game"].to_i }.uniq.first(3), "the top of Pricing's Unsold list"
  end
end
