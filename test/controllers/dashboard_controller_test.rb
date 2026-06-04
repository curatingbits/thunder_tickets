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

  test "redirects when season_id is invalid" do
    get dashboard_path(season_id: 999_999)
    assert_redirected_to login_path
  end
end
