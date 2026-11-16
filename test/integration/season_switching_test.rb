require "test_helper"

# Covers viewing past seasons: the season the user picks has to stick across
# pages, and it must never move the is_current flag.
#
# Assertions read the rendered page rather than controller ivars, so they
# describe what the user actually sees.
class SeasonSwitchingTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    @current = seasons(:current)
    @past = seasons(:past_season)
  end

  # Games listed on the page, by id, so we can prove scoping precisely.
  def listed_game_ids
    response.body.scan(%r{/games/(\d+)}).flatten.map(&:to_i).uniq.sort
  end

  def season_game_ids(season)
    season.games.pluck(:id).sort
  end

  test "dashboard defaults to the current season" do
    get dashboard_path

    assert_response :success
    assert_match "Thunder #{@current.year} Season", response.body
  end

  test "dashboard renders a past season when asked" do
    get dashboard_path(season_id: @past.id)

    assert_response :success
    assert_match "Thunder #{@past.year} Season", response.body
  end

  test "viewing a past season does not change which season is current" do
    get dashboard_path(season_id: @past.id)

    assert @current.reload.is_current?
    refute @past.reload.is_current?
  end

  test "the chosen season carries from the dashboard to the games list" do
    get dashboard_path(season_id: @past.id)
    get games_path

    assert_response :success
    assert_match "#{@past.year} Season", response.body
    assert_equal season_game_ids(@past), listed_game_ids
  end

  test "games list defaults to the current season" do
    get games_path

    assert_response :success
    assert_match "#{@current.year} Season", response.body
    assert_equal season_game_ids(@current), listed_game_ids
  end

  test "games list scopes to the requested season" do
    get games_path(season_id: @past.id)

    assert_response :success
    assert_equal season_game_ids(@past), listed_game_ids
  end

  test "filters stay inside the selected season" do
    get games_path(season_id: @past.id, filter: "past")

    assert_response :success
    # Every past-season game is in the past, so all of them survive the filter
    # and none of the current season's games leak in.
    assert_equal season_game_ids(@past), listed_game_ids
  end

  test "filter links preserve the selected season" do
    get games_path(season_id: @past.id)

    assert_match "/games?filter=upcoming&amp;season_id=#{@past.id}", response.body
  end

  test "switching back to the current season clears the remembered past season" do
    get dashboard_path(season_id: @past.id)
    get dashboard_path(season_id: @current.id)
    get games_path

    assert_equal season_game_ids(@current), listed_game_ids
  end

  test "an unknown season_id falls back to the current season" do
    get dashboard_path(season_id: 0)

    assert_response :success
    assert_match "Thunder #{@current.year} Season", response.body
  end

  test "a remembered season that is later deleted falls back to the current season" do
    get dashboard_path(season_id: @past.id)
    @past.destroy

    get games_path

    assert_response :success
    assert_match "#{@current.year} Season", response.body
  end

  test "a past season's game page uses its own season for seat math" do
    game = games(:past_regular)

    get game_path(game)

    assert_response :success
    # past_season holds 2 seats (the current season holds 3). Break-even is
    # total_cost / num_seats = (100*2 + 20) / 2 = 110.00. Reading the current
    # season's 3 seats here would render 73.33.
    assert_select "p", text: /Break even price per ticket:\s*\$110\.00/
    assert_select "p", text: /Your share of parking:\s*\$10\.00/
  end

  test "adding a game is hidden while viewing a past season" do
    get games_path(season_id: @past.id)
    assert_no_match(/Add Game/, response.body)

    get games_path(season_id: @current.id)
    assert_match(/Add Game/, response.body)
  end

  test "a past season is labelled as such on the games list" do
    get games_path(season_id: @past.id)

    assert_match(/Past season/, response.body)
  end

  test "the nav shows which season is being viewed, not just the current one" do
    get games_path(season_id: @past.id)
    assert_match "Season: <span class=\"text-warning font-semibold\">#{@past.year}</span> (viewing)", response.body

    get games_path(season_id: @current.id)
    assert_match "Season: <span class=\"text-accent font-semibold\">#{@current.year}</span>", response.body
    assert_no_match(/\(viewing\)/, response.body)
  end

  test "new games are always built on the current season, not the viewed one" do
    get dashboard_path(season_id: @past.id)

    assert_difference -> { @current.games.count }, 1 do
      post games_path, params: {
        game: {
          game_date: 1.month.from_now.to_date,
          opponent_id: teams(:nuggets).id,
          cost_per_ticket: 100,
          parking_cost: 20,
          game_type: "playoff",
          playoff_round: "First Round"
        }
      }
    end

    # The past season keeps only its own fixture playoff game; the new one
    # landed on the current season.
    assert_equal 0, @past.games.where(playoff_round: "First Round").count
  end
end
