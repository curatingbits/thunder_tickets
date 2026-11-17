require "test_helper"

class SeatMapsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 11, 16, 12)
    sign_in
    @game = game_with_snapshot("2026-11-18", 101)
  end

  def game_with_snapshot(date, number)
    game = seasons(:current).games.create!(game_number: number, game_date: Date.iso8601(date), opponent: teams(:rockets),
                                           cost_per_ticket: 162.52, parking_cost: 8.70, game_type: "regular")
    payload = Market::ScrapeFile.payloads(JSON.parse(file_fixture("tm_scrape_sample.json").read), captured_at: Time.current)
                                .find { |p| p[:event_date] == date }
    run = ImportRun.create!(kind: "market_research", source: "backfill", key: "t#{number}", status: "completed", started_at: Time.current)
    Market::ScanIngest.new(run: run, game: game, payload: payload).call
    game
  end

  test "the map page opens on the soonest game with every listing read, grouped by what it did to the value" do
    get seat_map_path

    assert_response :success
    assert_select "h1", "Seat map"
    assert_select "#seat-map[data-controller='seat-map'][data-seat-map-venue-value]"
    assert_select "#seat-map-game option[selected][value='#{@game.id}']"
    assert_select "[data-seat-map-target='item'][data-listing-id]", @game.market_snapshots.sole.observations.count
    assert_select "[data-seat-map-group='comparable'] [data-role='comparable']", minimum: 1
    groups = css_select("[data-seat-map-group]").map { |g| g["data-seat-map-group"] }
    assert_equal Market::SeatMap::ROLES.keys & groups, groups, "groups in role order"
    data = JSON.parse(css_select("[data-seat-map-target='data']").first["data-json"])
    assert_equal [ @game.id, [ 1, 2, 3 ] ], [ data["game"], data.dig("ours", "seats") ]
    assert_select "nav[aria-label='Main'] a[aria-current='page']", text: "Pricing"
  end

  test "a game's 3D button opens that game, and another game swaps only the frame" do
    other = game_with_snapshot("2026-12-16", 102)

    get seat_map_path(game_id: other.id)
    assert_select "#seat-map-game option[selected][value='#{other.id}']"

    get seat_map_path(game_id: @game.id), headers: { "Turbo-Frame" => SeatMapsController::FRAME }
    assert_response :success
    assert_select "turbo-frame##{SeatMapsController::FRAME}"
    assert_select "#seat-map-game option[selected][value='#{@game.id}']"
    assert_no_match "<html", response.body
  end

  test "three.js is pinned for the map but never preloaded, and nothing prefetches on hover" do
    get seat_map_path

    imports = JSON.parse(css_select("script[type='importmap']").first.text)["imports"]
    assert imports.key?("three")
    assert imports.key?("arena3d/viewer")
    assert_select "link[rel='modulepreload'][href*='three']", count: 0
    assert_select "link[rel='modulepreload'][href*='arena3d']", count: 0
    assert_select "meta[name='turbo-prefetch'][content='false']"
  end

  test "with no market data yet the page says so" do
    MarketSnapshot.update_all(invalidated_at: Time.current, invalidation_reason: "test")

    get seat_map_path
    assert_response :success
    assert_select "[data-seat-map-target='item']", count: 0
    assert_match "No market data for upcoming games yet", response.body
  end
end
