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

  test "the 3D seat map is off until switched on, and the choice is remembered" do
    get pricing_path
    assert_select "#seat-map", count: 0
    assert_select "[data-seat-map-switch][role='switch'][aria-checked='false']"

    get pricing_path(map: "on")
    assert_select "#seat-map[data-controller='seat-map'][data-seat-map-venue-value]"
    assert_select "[data-seat-map-switch][aria-checked='true']"

    get pricing_path
    assert_select "#seat-map", 1

    get pricing_path(map: "off")
    assert_select "#seat-map", count: 0
  end

  test "the seat map lists every listing read for the soonest game, grouped by what it did to the value" do
    get pricing_path(map: "on")

    assert_select "#seat-map-game option[selected][value='#{@game.id}']"
    assert_select "[data-seat-map-target='item'][data-listing-id]", @snapshot.observations.count
    assert_select "[data-seat-map-group='comparable'] [data-role='comparable']", minimum: 1
    groups = css_select("[data-seat-map-group]").map { |g| g["data-seat-map-group"] }
    assert_equal Market::SeatMap::ROLES.keys & groups, groups, "groups in role order"
    data = JSON.parse(css_select("[data-seat-map-target='data']").first["data-json"])
    assert_equal [ @game.id, [ 1, 2, 3 ] ], [ data["game"], data.dig("ours", "seats") ]
    assert_select "[data-seat-map-game-link='#{@game.id}']"
  end

  test "choosing another game swaps only the seat map frame" do
    other = seasons(:current).games.create!(game_number: 102, game_date: Date.new(2026, 12, 16), opponent: teams(:rockets),
                                            cost_per_ticket: 162.52, parking_cost: 8.70, game_type: "regular")
    payload = Market::ScrapeFile.payloads(JSON.parse(file_fixture("tm_scrape_sample.json").read), captured_at: Time.current)
                                .find { |p| p[:event_date] == "2026-12-16" }
    run = ImportRun.create!(kind: "market_research", source: "backfill", key: "t2", status: "completed", started_at: Time.current)
    Market::ScanIngest.new(run: run, game: other, payload: payload).call

    get pricing_path(map: "on", game_id: other.id), headers: { "Turbo-Frame" => "seat_map_listings" }

    assert_response :success
    assert_select "turbo-frame#seat_map_listings"
    assert_select "#seat-map-game option[selected][value='#{other.id}']"
    assert_select "[data-seat-map-group='set_aside']", 1, "the Kings game had courtside and Standard Admission listings"
    assert_select "[data-pricing-game]", count: 0
    assert_no_match "<html", response.body
  end

  test "three.js is pinned for the seat map but never preloaded" do
    get pricing_path(map: "on")

    imports = JSON.parse(css_select("script[type='importmap']").first.text)["imports"]
    assert imports.key?("three")
    assert imports.key?("arena3d/viewer")
    assert_select "link[rel='modulepreload'][href*='three']", count: 0
    assert_select "link[rel='modulepreload'][href*='arena3d']", count: 0
  end

  test "the game page links to its seats on the map" do
    get game_path(@game)
    assert_select "a[data-seat-map-link='#{@game.id}'][href=?]", pricing_path(map: "on", game_id: @game.id, anchor: "seat-map")
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

  test "home shows what the seats are worth" do
    get root_path
    assert_select "[data-dashboard-section='worth'] [data-pricing-tiles]"
  end
end
