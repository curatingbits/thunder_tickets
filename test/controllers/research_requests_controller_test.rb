require "test_helper"

# Update prices on the Pricing page, and the research panel it lives in.
class ResearchRequestsControllerTest < ActionDispatch::IntegrationTest
  FRAME = { "Turbo-Frame" => "research_panel" }.freeze

  setup do
    travel_to Time.zone.local(2026, 11, 21, 14)
    @user = sign_in
    seasons(:current).games.create!(game_number: 901, game_date: Date.new(2026, 11, 23), opponent: teams(:rockets),
                                    cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
  end

  def run!(key, status: "running", finished_at: nil)
    ImportRun.create!(kind: "market_research", source: "ticketmaster_browser", key: key, status: status,
                      started_at: 10.minutes.ago, last_activity_at: Time.current, finished_at: finished_at)
  end

  test "Pricing offers Update prices: the next 7 days or all games, with how long each takes" do
    soon = ResearchRequest.target_count("soon", season: seasons(:current))
    get pricing_path

    assert_select "turbo-frame#research_panel[data-controller='research-panel']" do
      assert_select "[data-research-state='idle']"
      assert_select "a[href='#{import_runs_path}'][data-turbo-frame='_top']"
      assert_select "details[data-research-update] summary", /Update prices/
      assert_select "form[action='#{research_requests_path}'] input[name='scope'][value='soon']"
      assert_select "button[data-research-scope='soon']", /Next 7 days\s+#{soon} games? · about \d+ min/
      assert_select "button[data-research-scope='all']", /All games/
    end
  end

  test "pressing it asks Duggan's computer; the panel waits with Cancel" do
    post research_requests_path, params: { scope: "soon" }, headers: FRAME
    assert_redirected_to research_requests_path
    request = ResearchRequest.last
    assert_equal [ @user, "soon", "pending" ], [ request.user, request.scope, request.status ]

    get research_requests_path, headers: FRAME
    assert_select "turbo-frame#research_panel [data-research-state='pending']", /Waiting for Duggan's computer/
    assert_select "[data-research-state='pending']", /Next 7 days, asked for by #{@user.name}/
    assert_select "form[action='#{cancel_research_request_path(request)}']"
    assert_select "[data-research-update]", count: 0

    post cancel_research_request_path(request), headers: FRAME
    assert_redirected_to research_requests_path
    assert_equal "cancelled", request.reload.status
  end

  test "a second request while one waits is turned away, saying why" do
    ResearchRequest.request!(user: @user, scope: "all")

    post research_requests_path, params: { scope: "soon" }, headers: FRAME
    assert_response :unprocessable_entity
    assert_select "[role='alert']", /already waiting/
    assert_equal 1, ResearchRequest.count
  end

  test "outside the panel's frame it goes back to Pricing" do
    post research_requests_path, params: { scope: "all" }
    assert_redirected_to pricing_path
    assert_equal "all", ResearchRequest.last.scope
  end

  test "while research runs, the panel shows how far it's got and who asked" do
    request = ResearchRequest.request!(user: @user, scope: "soon")
    ResearchRequest.claim!(client_id: "quattro-requests")
    get research_requests_path, headers: FRAME
    assert_select "[data-research-state='starting']", /Starting on Duggan's computer/

    run!(request.run_key)
    of = ResearchRequest.target_count("soon", season: seasons(:current))
    get pricing_path
    assert_select "[data-research-state='running']" do
      assert_select "p", /Researching prices: 0 of #{of} games read/
      assert_select "p", /Next 7 days, asked for by #{@user.name}/
      assert_select "[role='progressbar'][aria-valuenow='0'][aria-valuemax='#{of}']"
    end
  end

  test "the scheduled research shows the same way" do
    run!("tm-2026-11-21")
    get pricing_path
    assert_select "[data-research-state='running']", /The scheduled research/
  end

  test "after a Ticketmaster block, the choices give way to when updates resume" do
    run!("tm-2026-11-21", status: "blocked", finished_at: 2.hours.ago)
    get pricing_path

    assert_select "[data-research-unavailable]", /paused until Sun 12:00 PM/
    assert_select "[data-research-update]", count: 0
  end

  test "the last request's problem stays on the panel for a while" do
    ResearchRequest.request!(user: @user, scope: "soon")
    travel 61.minutes
    get pricing_path

    assert_select "[data-research-note]", /didn't pick it up within an hour/
    assert_select "[data-research-update]"
  end

  test "signed out, nothing can be asked for" do
    delete logout_path
    post research_requests_path, params: { scope: "soon" }

    assert_redirected_to login_path
    assert_equal 0, ResearchRequest.count
  end
end
