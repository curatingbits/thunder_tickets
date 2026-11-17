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
