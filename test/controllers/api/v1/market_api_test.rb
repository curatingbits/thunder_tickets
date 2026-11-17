require "test_helper"

class Api::V1::MarketApiTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 11, 16, 12)
    _, @raw = ApiToken.generate!(name: "research", scopes: [ "market:write" ])
    @game = seasons(:current).games.create!(game_number: 101, game_date: Date.new(2026, 11, 18), opponent: teams(:rockets),
                                            cost_per_ticket: 162.52, parking_cost: 8.70, game_type: "regular")
    file = JSON.parse(file_fixture("tm_scrape_sample.json").read)
    @scan = Market::ScrapeFile.payloads(file, captured_at: Time.current).find { |p| p[:event_date] == "2026-11-18" }
  end

  def auth(raw = @raw)
    { "Authorization" => "Bearer #{raw}" }
  end

  def start_run(client: "client-a", key: "tm-2026-W47")
    post api_v1_import_runs_path, params: { kind: "market_research", source: "ticketmaster_browser", key: key,
                                            client_id: client, agent_version: "test" }, headers: auth, as: :json
    response.parsed_body
  end

  def post_scan(run_id, client: "client-a", scan: @scan, game: @game)
    post api_v1_import_run_market_scans_path(run_id), params: scan.merge(client_id: client, game_id: game.id),
                                                      headers: auth, as: :json
  end

  test "no token, an unknown token, or a revoked one is turned away" do
    get api_v1_research_targets_path
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body.dig("error", "code")

    get api_v1_research_targets_path, headers: auth("madr_wrong")
    assert_response :unauthorized

    ApiToken.find_by(name: "research").revoke!
    get api_v1_research_targets_path, headers: auth
    assert_response :unauthorized
  end

  test "a token without the scope is forbidden" do
    _, read_only = ApiToken.generate!(name: "reader", scopes: [ "read" ])
    get api_v1_research_targets_path, headers: auth(read_only)
    assert_response :forbidden
  end

  test "the mid-week rescan asks for the next week's games only" do
    soon = seasons(:current).games.create!(game_number: 950, game_date: Date.current + 3, opponent: teams(:rockets),
                                           cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
    get api_v1_research_targets_path, params: { within_days: 7 }, headers: auth
    assert_equal [ @game.id, soon.id ], response.parsed_body["games"].map { |g| g["id"] }
    get api_v1_research_targets_path, headers: auth
    assert_operator response.parsed_body["games"].size, :>, 2

    get api_v1_research_targets_path, params: { within_days: "lots" }, headers: auth
    assert_response :unprocessable_entity
  end

  test "research targets: upcoming games, the sections and how to start" do
    get api_v1_research_targets_path, headers: auth

    assert_response :success
    body = response.parsed_body
    assert_equal [ "101", "102", "120" ], body["sections"]
    assert_equal 2, body["quantity"]
    assert_match %r{ticketmaster.com/oklahoma-city-thunder-tickets}, body["start_url"]
    game = body["games"].find { |g| g["id"] == @game.id }
    assert_equal [ "2026-11-18", 3 ], game.values_at("date", "seats_to_sell")
    assert_not body["games"].any? { |g| g["id"] == games(:current_past).id }
  end

  test "a whole run: start, resume, scan, replay, finish" do
    run = start_run
    assert_response :created
    start_run
    assert_response :ok

    post_scan(run["id"])
    assert_response :created
    created = response.parsed_body
    assert_equal false, created["replayed"]
    assert_equal "competitive", created.dig("recommended", "strategy")
    assert created.dig("prices_all_in", "market").positive?
    assert_includes %w[listed not_listed unconfirmed], created.dig("our_listing", "outcome"), "the research checks our own row"

    post_scan(run["id"])
    assert_response :ok
    assert_equal true, response.parsed_body["replayed"]
    assert_nil response.parsed_body["our_listing"], "a replay changes nothing"
    assert_equal 1, MarketSnapshot.count

    patch api_v1_import_run_path(run["id"]), params: { client_id: "client-a", status: "completed", targeted: 2,
                                                       notes: "1 game had no listings", errors: [ "Jan 30: no Paycom event" ] },
                                             headers: auth, as: :json
    assert_response :success
    finished = response.parsed_body
    assert_equal "partial", finished["status"]
    assert_equal [ @game.id ], finished["scanned_game_ids"]
    assert_equal "Jan 30: no Paycom event", finished["errors"].first["message"]
    assert_equal 1, finished["results"].size
  end

  test "another client can't take a live run, or post scans to it" do
    run = start_run
    start_run(client: "client-b")
    assert_response :conflict

    post_scan(run["id"], client: "client-b")
    assert_response :conflict
    assert_equal "not_holder", response.parsed_body.dig("error", "code")
  end

  test "the seat numbers the reader read decide whether a Row DD listing is ours" do
    run = start_run
    scan = @scan.deep_dup
    scan[:listings] << { position: 998, section: "101", row: "DD", price: 151.88, ticket_type: "verified_resale", seats: [ 6, 7 ] }
    scan[:listings] << { position: 999, section: "101", row: "DD", price: 194.40, ticket_type: "verified_resale", seats: [ 1, 2 ] }
    post_scan(run["id"], scan: scan)

    assert_response :created
    assert_equal [ "listed", 194.4, [ 1, 2 ] ], response.parsed_body["our_listing"].values_at("outcome", "price", "seen_seats")
    assert_equal BigDecimal("194.4"), @game.listings.sole.ask_price
  end

  test "the second look at our seat count comes through the API" do
    run = start_run
    scan = @scan.merge(quantity_check: { quantity: 3, complete: true, read: 75, total: 75,
                                         listings: [ { price: 309.83, seats: [ 1, 2, 3 ], raw_label: "Sec 101 • Row DD [Seats 1-3]" } ] })
    post_scan(run["id"], scan: scan)

    assert_response :created
    assert_equal [ "listed", 309.83, [ 1, 2, 3 ] ], response.parsed_body["our_listing"].values_at("outcome", "price", "seen_seats")
  end

  test "a different scan for the same game, or the wrong night, is refused" do
    run = start_run
    post_scan(run["id"])

    changed = @scan.deep_dup
    changed[:listings].first[:price] += 5
    post_scan(run["id"], scan: changed)
    assert_response :conflict

    other = seasons(:current).games.create!(game_number: 102, game_date: Date.new(2026, 11, 20), opponent: teams(:clippers),
                                            cost_per_ticket: 162.52, parking_cost: 8.70, game_type: "regular")
    post_scan(run["id"], game: other)
    assert_response :unprocessable_entity
    assert_match(/doesn't match/, response.parsed_body.dig("error", "message"))
  end

  test "oversized bodies are refused" do
    post api_v1_import_runs_path, params: { kind: "market_research", padding: "x" * (1.megabyte + 10) },
                                  headers: auth, as: :json
    assert_response :payload_too_large
  end

  test "requests are rate limited per token" do
    Api::V1::BaseController::RATE_STORE.clear
    120.times { get api_v1_research_targets_path, headers: auth }
    assert_response :success
    get api_v1_research_targets_path, headers: auth
    assert_response :too_many_requests
  ensure
    Api::V1::BaseController::RATE_STORE.clear
  end

  test "the API needs no CSRF token, while HTML forms still require one" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    start_run
    assert_response :created

    post login_path, params: { email: users(:admin).email, password: "password" }
    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
