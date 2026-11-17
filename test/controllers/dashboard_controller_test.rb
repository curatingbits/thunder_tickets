require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in }

  test "redirects to login when not authenticated" do
    delete logout_path
    get dashboard_path
    assert_redirected_to login_path
  end

  test "renders the current (active) season dashboard" do
    get dashboard_path
    assert_response :success
    assert_select "h1", text: "Dashboard"
    # active badge present, recap framing absent
    assert_match "Active", response.body
    assert_no_match "Season Recap", response.body
  end

  test "renders a completed season in recap mode via season_id" do
    get dashboard_path(season_id: seasons(:past_season).id)
    assert_response :success
    assert_match "Recap", response.body
    assert_match "Season Recap", response.body
    assert_match "Write-Off", response.body
    # forward-looking framing should be gone in recap mode
    assert_no_match "to go", response.body
  end

  test "shows the season switcher when multiple seasons exist" do
    get dashboard_path
    assert_response :success
    assert_select "select[data-action='change->season-switcher#navigate']"
  end

  test "viewing another season does not change the current season" do
    get dashboard_path(season_id: seasons(:past_season).id)
    assert_response :success
    assert seasons(:current).reload.is_current, "current season must remain is_current"
  end

  # An unknown season_id used to redirect to the login page, which is a
  # confusing answer to a stale bookmark. It now falls back to the current
  # season; see SeasonSwitchingTest for the rest of the fallback behaviour.
  test "falls back to the current season when season_id is invalid" do
    get dashboard_path(season_id: 999_999)
    assert_response :success
    assert_match seasons(:current).year, response.body
  end

  test "the profit chart marks unplayed, unsold games as pending" do
    get dashboard_path

    data = JSON.parse(css_select("canvas[data-dashboard-charts-target='profitChart']").first["data-game-profits"])
    by_opponent = data.index_by { |g| g["opponent"] }
    assert_equal false, by_opponent["DAL"]["pending"] # current_past: played, 2 sold
    assert_equal true,  by_opponent["DEN"]["pending"] # current_future: nothing sold yet
  end

  test "losses render with a leading minus, never as $-N or +$-N" do
    # Every current-season game is underwater, so even the Top Performer
    # (current_past: 250 revenue - 320 cost) is a loss.
    get dashboard_path

    assert_response :success
    assert_select "a[href='#{game_path(games(:current_past))}'] p.text-negative", text: "-$70"
    assert_no_match(/\$-\d/, response.body)
    assert_no_match(/\+\$-/, response.body)
  end
  test "needs attention lists next week's unsold games for the current season" do
    sign_in
    soon = seasons(:current).games.create!(game_number: 90, game_date: Date.current + 2, opponent: teams(:rockets),
                                           cost_per_ticket: 100, parking_cost: 10, game_type: "regular")

    get dashboard_path

    assert_select "[data-dashboard-section='attention'] li[data-attention-kind='unsold_soon']", count: 1
    assert_select "[data-dashboard-section='attention'] a[href=?]", game_path(soon), text: /3 seats to sell vs Houston Rockets/
    assert_select "[data-dashboard-section='next-games'] a[href=?]", game_path(soon)
  end

  test "an empty attention list says all clear" do
    sign_in
    get dashboard_path

    assert_select "[data-dashboard-section='attention']", text: /All clear/
  end

  test "a past season shows neither attention nor next games" do
    sign_in
    get dashboard_path(season_id: seasons(:past_season).id)

    assert_select "[data-dashboard-section='attention']", count: 0
    assert_select "[data-dashboard-section='next-games']", count: 0
    assert_select "[data-dashboard-section='next-unsold']", count: 0
    assert_select "[data-dashboard-section='payouts']", count: 0
  end

  test "with every upcoming game sold, the next unsold games say so" do
    (1..3).each { |seat| games(:current_future).tickets.create!(seat_number: seat, sale_price: 150) }

    get dashboard_path

    assert_select "[data-dashboard-section='next-unsold']", text: /No unsold games coming up/
    assert_select "[data-dashboard-section='next-unsold'] [data-pricing-game]", count: 0
  end
end
