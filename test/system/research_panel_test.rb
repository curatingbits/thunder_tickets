require "application_system_test_case"

# Update prices end to end in the browser: the request waits, Duggan's
# computer claims it, its run reads games, and when the run finishes the
# page reloads with the panel back to idle.
class ResearchPanelTest < ApplicationSystemTestCase
  setup do
    travel_to Time.zone.local(2026, 11, 21, 14)
    seasons(:current).games.create!(game_number: 901, game_date: Date.new(2026, 11, 23), opponent: teams(:rockets),
                                    cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
  end

  test "the panel follows an update from asking to finished" do
    sign_in_via_form
    visit pricing_path
    find("[data-research-update] summary").click
    find("button[data-research-scope='soon']").click

    assert_selector "[data-research-state='pending']", text: "Waiting for Duggan's computer"
    request = ResearchRequest.last

    ResearchRequest.claim!(client_id: "quattro-requests")
    assert_selector "[data-research-state='starting']", text: "Starting on Duggan's computer"

    run = ImportRun.create!(kind: "market_research", source: "ticketmaster_browser", key: request.run_key, status: "running",
                            started_at: Time.current, last_activity_at: Time.current)
    assert_selector "[data-research-state='running']", text: "Researching prices: 0 of"

    run.update!(status: "completed", finished_at: Time.current)
    assert_selector "[data-research-state='idle']", text: "Last research: completed"
    assert_no_selector "turbo-frame#research_panel[src]", wait: 0.1
  end

  test "cancelling a waiting update brings the choices back" do
    sign_in_via_form
    visit pricing_path
    find("[data-research-update] summary").click
    find("button[data-research-scope='all']").click
    click_on "Cancel"

    assert_selector "[data-research-state='idle'] [data-research-update]"
    assert_equal "cancelled", ResearchRequest.last.status
  end
end
