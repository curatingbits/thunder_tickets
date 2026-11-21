require "test_helper"

class ResearchRequestTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.local(2026, 11, 21, 14) # a Saturday
    @user = users(:admin)
  end

  def run!(key, status: "running", started_at: Time.current, finished_at: nil)
    ImportRun.create!(kind: "market_research", source: "ticketmaster_browser", key: key, status: status,
                      started_at: started_at, last_activity_at: Time.current, finished_at: finished_at)
  end

  def claimed_request(scope = "soon")
    request = ResearchRequest.request!(user: @user, scope: scope)
    ResearchRequest.claim!(client_id: "quattro-requests")
    request.reload
  end

  test "a request waits for the computer, and a second can't be made meanwhile" do
    request = ResearchRequest.request!(user: @user, scope: "soon")

    assert_equal [ "pending", "pending" ], [ request.status, request.state ]
    assert_equal "tm-req-#{request.id}", request.run_key
    error = assert_raises(ResearchRequest::Refused) { ResearchRequest.request!(user: @user, scope: "all") }
    assert_match "already waiting for Duggan's computer", error.message
  end

  test "only the next 7 days or all games" do
    assert_raises(ResearchRequest::Refused) { ResearchRequest.request!(user: @user, scope: "everything") }
    assert_equal [ 7, nil ], %w[soon all].map { |scope| ResearchRequest.new(scope: scope).within_days }
  end

  test "a request the computer doesn't pick up within an hour lapses, and stops holding the button" do
    old = ResearchRequest.request!(user: @user, scope: "soon")
    travel 61.minutes

    assert_equal "expired", old.state
    assert_equal Time.zone.local(2026, 11, 21, 15), old.settled_at
    assert_nil ResearchRequest.unavailable_reason
    fresh = ResearchRequest.request!(user: @user, scope: "all")
    assert_equal "expired", old.reload.status, "making a new one settles the old one"
    assert_equal "pending", fresh.state
  end

  test "the computer claims the oldest waiting request, but not while research is running" do
    request = ResearchRequest.request!(user: @user, scope: "soon")
    scheduled = run!("tm-2026-11-21")

    claimed, why = ResearchRequest.claim!(client_id: "quattro-requests")
    assert_nil claimed
    assert_match "already running (tm-2026-11-21)", why
    assert_equal "pending", request.reload.status

    scheduled.update!(status: "completed", finished_at: Time.current)
    claimed, = ResearchRequest.claim!(client_id: "quattro-requests")
    assert_equal request, claimed
    assert_equal [ "claimed", "quattro-requests", "starting" ], [ claimed.status, claimed.client_id, claimed.state ]
    assert_equal [ nil, "nothing is waiting" ], ResearchRequest.claim!(client_id: "quattro-requests")
  end

  test "the run started with its key takes it from starting to running to finished" do
    request = claimed_request("all")
    assert_match "starting on Duggan's computer", ResearchRequest.unavailable_reason

    run = run!(request.run_key)
    assert_equal "running", request.reload.state
    assert_nil request.settled_at
    assert_equal "Research is already running.", ResearchRequest.unavailable_reason
    assert_equal request, ResearchRequest.for_run(run)

    run.update!(status: "completed", finished_at: Time.current)
    assert_equal "finished", request.reload.state
    assert_equal run.finished_at, request.settled_at
  end

  test "a claimed request whose run never appears didn't start, and stops holding the button" do
    request = claimed_request
    travel 16.minutes

    assert_equal "did_not_start", request.reload.state
    assert_nil ResearchRequest.unavailable_reason
    ResearchRequest.expire_stale!
    assert_equal [ "failed", "Duggan's computer didn't start the research." ], [ request.reload.status, request.error ]
  end

  test "a run that stops checking in has stopped, and the button comes back" do
    request = claimed_request
    run!(request.run_key)
    travel ImportRun::LEASE + 1.minute

    assert_equal "stopped", request.reload.state
    assert_nil ResearchRequest.unavailable_reason
  end

  test "updates pause for a day after Ticketmaster blocks a run" do
    run!("tm-2026-11-21", status: "blocked", started_at: 3.hours.ago, finished_at: 2.hours.ago)

    error = assert_raises(ResearchRequest::Refused) { ResearchRequest.request!(user: @user, scope: "soon") }
    assert_match "paused until Sun 12:00 PM", error.message
    travel 22.hours
    assert ResearchRequest.unavailable_reason
    travel 1.minute
    assert_nil ResearchRequest.unavailable_reason
  end

  test "a block after the request was made lapses it instead of starting it" do
    request = ResearchRequest.request!(user: @user, scope: "soon")
    run!("tm-2026-11-21", status: "blocked", finished_at: Time.current)

    assert_equal [ nil, "Ticketmaster blocked a run, so updates are paused" ], ResearchRequest.claim!(client_id: "q")
    assert_equal "expired", request.reload.status
    assert_match "blocked", request.error
  end

  test "two Update prices runs a day; scheduled runs and requests that never ran don't count" do
    run!("tm-2026-11-21", status: "completed", finished_at: Time.current)
    ResearchRequest.request!(user: @user, scope: "soon").cancel!
    2.times do
      request = claimed_request
      run!(request.run_key, status: "completed", finished_at: Time.current)
    end

    error = assert_raises(ResearchRequest::Refused) { ResearchRequest.request!(user: @user, scope: "all") }
    assert_match "2 updates have already run today", error.message
    travel_to Time.zone.local(2026, 11, 22, 0, 5)
    assert_nil ResearchRequest.unavailable_reason
  end

  test "only a waiting request can be cancelled" do
    request = ResearchRequest.request!(user: @user, scope: "soon")
    request.cancel!

    assert_equal "cancelled", request.reload.state
    assert_raises(ResearchRequest::Refused) { request.cancel! }
    assert_raises(ResearchRequest::Refused) { claimed_request.cancel! }
  end

  test "the computer can say it couldn't start what it claimed" do
    request = claimed_request
    request.fail!("research-window: Hyprland isn't running")

    assert_equal [ "failed", "research-window: Hyprland isn't running" ], [ request.state, request.error ]
    assert_raises(ResearchRequest::Refused) { request.fail!("again") }
    assert_raises(ResearchRequest::Refused) { ResearchRequest.request!(user: @user, scope: "all").fail!("not claimed") }
  end

  test "it counts the games a run would read the way the research targets do" do
    season = seasons(:current)
    season.games.create!(game_number: 901, game_date: Date.new(2026, 11, 23), opponent: teams(:rockets),
                         cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
    season.games.create!(game_number: 902, game_date: Date.new(2026, 12, 20), opponent: teams(:rockets),
                         cost_per_ticket: 100, parking_cost: 10, game_type: "regular")

    assert_equal season.games.upcoming.where(game_date: ..Date.new(2026, 11, 28)).count,
                 ResearchRequest.target_count("soon", season: season)
    assert_equal season.games.upcoming.count, ResearchRequest.target_count("all", season: season)
  end
end
