require "test_helper"

class InsightsAndReportsTest < ActionDispatch::IntegrationTest
  setup do
    @season = seasons(:current)
    travel_to Time.zone.local(2026, 11, 18, 12)
    @games = %i[rockets clippers mavericks].each_with_index.map do |team, i|
      @season.games.create!(game_number: 700 + i, game_date: Date.new(2026, 12, 4) + i * 3, opponent: teams(team),
                            cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
    end
  end

  def scan(at, games, value: 250)
    run = ImportRun.create!(kind: "market_research", source: "ticketmaster_browser", key: "scan-#{at.to_i}",
                            status: "completed", started_at: at)
    games.each_with_index do |game, i|
      MarketSnapshot.create!(import_run: run, game: game, captured_at: at, days_to_game: (game.game_date - at.to_date).to_i,
                             payload_digest: SecureRandom.hex, engine_version: "1", buyer_fee_multiplier: 1.215, fee_verified: true,
                             market_value: value + 50 * i, competitive_price: 225, premium_price: 300, recommended_strategy: "market",
                             recommended_list_price: 206, confidence: 80, section_count: 8)
    end
  end

  test "insights need a login, and say so when there isn't enough data" do
    get insights_path
    assert_redirected_to login_path

    sign_in
    get insights_path
    assert_response :success
    assert_select "[data-insights-empty]"
  end

  test "insights compare opponents and days out once there's data" do
    scan(Time.zone.local(2026, 11, 16, 6, 30), @games)
    sign_in
    get insights_path

    assert_select "[data-insight='opponents'] [data-insight-group]", count: 3
    assert_select "[data-insight='opponents'] [data-insight-group]:first-child", text: /Dallas Mavericks.*\+17%/m
    assert_select "[data-insight='supply']", text: /One scan so far/
    assert_select "[data-insight='sales']", text: /No sales to compare yet/
  end

  test "the weekly report shows this week, steps back, and won't show the future" do
    sign_in
    get weekly_report_path
    assert_response :success
    assert_select "h1", "Week of Nov 16"
    assert_select "[data-weekly-section='upcoming']"
    assert_select "a[href=?]", weekly_report_path(week: "2026-11-09")

    get weekly_report_path(week: "2026-11-09")
    assert_select "h1", "Week of Nov 9"
    assert_select "[data-weekly-quiet]"
    assert_select "[data-weekly-section='upcoming']", count: 0

    get weekly_report_path(week: "2026-12-07")
    assert_redirected_to weekly_report_path

    get weekly_report_path(week: "soon")
    assert_redirected_to weekly_report_path
  end

  test "the weekly report API needs a token" do
    get api_v1_weekly_report_path
    assert_response :unauthorized

    _, raw = ApiToken.generate!(name: "kate", scopes: [ "read" ])
    get api_v1_weekly_report_path, params: { week: "2026-11-10" }, headers: { "Authorization" => "Bearer #{raw}" }
    assert_response :success
    assert_equal [ "2026-11-09", false ], response.parsed_body.values_at("week_start", "current")
  end

  test "a game's page charts its price once it has two scans" do
    game = @games.first
    scan(Time.zone.local(2026, 11, 9, 6, 30), [ game ], value: 240)
    sign_in
    get game_path(game)
    assert_select "[data-price-history]", text: /One scan so far/
    assert_select "[data-controller='price-history-chart']", count: 0

    scan(Time.zone.local(2026, 11, 16, 6, 30), [ game ], value: 260)
    get game_path(game)
    assert_select "[data-controller='price-history-chart'] canvas[data-points]"
    assert_select "[data-price-history] table tbody tr", count: 2
  end

  test "the reports are a tap away from More, Home and Pricing" do
    sign_in
    get more_path
    assert_select "a[href=?]", weekly_report_path
    assert_select "a[href=?]", insights_path

    get root_path
    assert_select "a[href=?]", weekly_report_path

    get pricing_path
    assert_select "a[href=?]", insights_path
  end
end
