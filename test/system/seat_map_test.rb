require "application_system_test_case"
require "mobile_system_test_case"

# The 3D seat map on Pricing, drawn with software WebGL: switched on, it shows
# the four sections, and the list and the 3D view pick each other.
module SeatMapSetup
  def build_games
    travel_to Time.zone.local(2026, 11, 16, 12)
    sample = JSON.parse(file_fixture("tm_scrape_sample.json").read)
    payloads = Market::ScrapeFile.payloads(sample, captured_at: Time.current).index_by { |p| p[:event_date] }
    @game = game_on("2026-11-18", 101)
    hawks = payloads.fetch("2026-11-18").deep_dup
    @near = hawks[:listings].find { |l| l[:section] == "101" && %w[AA BB CC EE FF GG].include?(l[:row]) }
    @near[:seats] = [ 4, 5 ]
    ingest(@game, hawks, "t1")
    @other = game_on("2026-12-16", 102)
    ingest(@other, payloads.fetch("2026-12-16"), "t2")
  end

  def game_on(date, number)
    seasons(:current).games.create!(game_number: number, game_date: Date.iso8601(date), opponent: teams(:rockets),
                                    cost_per_ticket: 162.52, parking_cost: 8.70, game_type: "regular")
  end

  def ingest(game, payload, key)
    run = ImportRun.create!(kind: "market_research", source: "backfill", key: key, status: "completed", started_at: Time.current)
    Market::ScanIngest.new(run: run, game: game, payload: payload).call.snapshot
  end

  def near_id
    @game.market_snapshots.sole.observations.find_by!(position: @near[:position]).id.to_s
  end

  def assert_map_ready
    assert_selector "#seat-map[data-seat-map-state='ready']", wait: 20
  end

  def screenshot(name)
    save_screenshot(Rails.root.join("tmp/screenshots/seat_map_#{name}.png")) if ENV["SEAT_MAP_SCREENSHOTS"]
  end
end

class SeatMapTest < ApplicationSystemTestCase
  include SeatMapSetup

  setup { build_games }

  test "a game's 3D button opens its map; a seat picks its listing and the list picks its seats" do
    sign_in_via_form
    visit pricing_path
    page.execute_script("document.querySelector('tr[data-pricing-game]').scrollIntoView({ block: 'center' })")
    screenshot("board")
    within("tr[data-pricing-game='#{@game.id}']") { click_on "3D" }

    assert_selector "h1", text: "Seat map"
    assert_selector "#seat-map-game option[selected][value='#{@game.id}']"
    assert_map_ready
    assert_equal 1, page.evaluate_script("window.__seatMapCount")
    screenshot("desktop")

    # The 3D view gets the room: as wide as the page allows beside the list, and nearly as tall as the window.
    stage = page.evaluate_script("document.getElementById('seat-map-stage').getBoundingClientRect().toJSON()")
    list = page.evaluate_script("document.querySelector('[data-seat-map-target=list]').getBoundingClientRect().toJSON()")
    assert_operator list["left"], :>=, stage["right"], "the list sits beside the 3D view"
    assert_operator stage["height"], :>=, 700

    # A tap on the seats of the listing near DD picks it in the list.
    point = page.evaluate_script("window.__seatMap.screenPoint('#{near_id}')")
    page.driver.browser.action.move_to_location(point["x"].round, point["y"].round).click.perform
    assert_selector "[data-listing-id='#{near_id}'][aria-pressed='true']"
    assert_equal [ near_id ], page.evaluate_script("window.__seatMap.selected")
    screenshot("desktop_picked")

    # A listing picked in the list lights up in 3D.
    item = find("[data-role='baseline']", match: :first)
    item.click
    assert_selector "[data-listing-id='#{item['data-listing-id']}'][aria-pressed='true']"
    assert_selector "[data-listing-id='#{near_id}'][aria-pressed='false']"
    assert_equal [ item["data-listing-id"] ], page.evaluate_script("window.__seatMap.viewerSelected()")

    # The light theme repaints the 3D view along with the page.
    within("[data-shell='sidebar']") { click_on "Light" }
    assert_selector "html[data-theme='light']"
    assert_map_ready
    screenshot("desktop_light")
  end

  test "another game swaps the list and the 3D view's data; leaving the page lets go of the 3D view" do
    sign_in_via_form
    visit seat_map_path
    assert_selector "#seat-map-game option[selected][value='#{@game.id}']", wait: 5
    assert_map_ready

    select "Wed, Dec 16 · #{@other.opponent.name}", from: "seat-map-game"
    # The first software-rendered 3D frame can hold the page up for a few seconds on CI.
    assert_selector "#seat-map-game option[selected][value='#{@other.id}']", wait: 15
    assert_current_path(/game_id=#{@other.id}/)
    assert_selector "[data-seat-map-target='item']", count: @other.market_snapshots.sole.observations.count
    assert_map_ready
    assert_equal 1, page.evaluate_script("window.__seatMapCount"), "the same 3D view, not a second one"
    assert_equal [], page.evaluate_script("window.__seatMap.viewerSelected()")

    within("[data-shell='sidebar']") { click_on "Games" }
    assert_selector "h1", text: "Games"
    assert_equal 0, page.evaluate_script("window.__seatMapCount")
  end

  test "Pricing itself loads nothing 3D, and its header link opens the map on the soonest game" do
    sign_in_via_form
    visit pricing_path
    assert_no_selector "#seat-map"
    assert_nil page.evaluate_script("window.__seatMapCount")

    click_on "3D seat map →"
    assert_selector "#seat-map-game option[selected][value='#{@game.id}']"
    assert_map_ready
  end
end

class SeatMapMobileTest < MobileSystemTestCase
  include SeatMapSetup

  setup { build_games }

  test "on a phone a game card's 3D button opens its map, the 3D view on top and the list under it" do
    sign_in_via_form
    visit pricing_path
    page.execute_script("document.querySelector('li.relative').scrollIntoView({ block: 'center' })")
    screenshot("phone_cards")
    find("a[data-seat-map-game-link='#{@other.id}']").click

    assert_selector "#seat-map-game option[selected][value='#{@other.id}']"
    assert_map_ready
    stage = page.evaluate_script("document.getElementById('seat-map-stage').getBoundingClientRect().toJSON()")
    list = page.evaluate_script("document.querySelector('[data-seat-map-target=list]').getBoundingClientRect().toJSON()")
    assert_operator stage["width"], :<=, 390
    assert_operator stage["height"], :>=, 844 * 0.5
    assert_operator list["top"], :>=, stage["bottom"]
    page.execute_script("document.getElementById('seat-map-stage').scrollIntoView({ block: 'start' })")
    screenshot("phone")
  end
end
