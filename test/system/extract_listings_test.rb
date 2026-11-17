require "application_system_test_case"

# The Ticketmaster page reader (automation/skills/ticketmaster-pricing/
# extract_listings.js) against a stand-in page with the parts it relies on:
# a list that loads as it scrolls, a quantity menu, and Row DD cards that
# open a "Ticket Selection" panel saying which seats you'd get.
class ExtractListingsTest < ApplicationSystemTestCase
  READER = Rails.root.join("automation/skills/ticketmaster-pricing/extract_listings.js").read
  PAGE = Rails.root.join("test/fixtures/files/tm_event_page.html")

  def read_page(query = "", our_quantity: 3)
    visit "file://#{PAGE}#{query}"
    page.execute_script("window.__madrSections = ['101', '102', '120']; " \
                        "window.__madrOurs = { section: '101', row: 'DD', quantity: #{our_quantity} };")
    # Assigned, not returned: the file opens with comments, and "return" + a
    # comment line would return before the code.
    page.execute_script("window.__readerStarted = #{READER}")
    assert_equal "started", page.evaluate_script("window.__readerStarted")
    Timeout.timeout(90) { sleep 0.5 until page.evaluate_script("window.__madr.status") != "running" }
    JSON.parse(page.evaluate_script("window.__madrMeta()"))
  end

  test "prices at 2 tickets, and finds our 3-seat listing by looking again at 3" do
    meta = read_page

    assert_equal [ "done", true, 12, 11 ], meta.values_at("status", "scroll_complete", "event_total_listings", "kept")
    assert_equal [ { "price" => 151.88, "seats" => [ 6, 7 ] } ], meta["our_row"], "someone else's pair shows at 2"
    check = meta["quantity_check"]
    assert_equal [ 3, true ], check.values_at("quantity", "complete")
    assert_equal [ [ 309.83, [ 1, 2, 3 ] ] ], check["listings"].map { |l| l.values_at("price", "seats") }
    assert_match "[Seats 1-3]", check["listings"].first["raw_label"]

    rows = JSON.parse(page.evaluate_script("window.__madrChunk(0, 20)"))
    assert_equal [ 6, 7 ], rows.find { |r| r[2] == "DD" }[6]
    assert_nil rows.find { |r| r[2] == "K" }[6], "seats are read only in our row"
    assert_not page.evaluate_script("!!window.reserved"), "never presses Reserve Tickets"
    assert_no_selector "#panel"
  end

  test "finds the quantity button by its text when it has no aria-label" do
    meta = read_page("?label=text&start=3")

    assert_equal [ "done", 12, 11 ], meta.values_at("status", "event_total_listings", "kept")
    check = meta["quantity_check"]
    assert_equal [ 3, true ], check.values_at("quantity", "complete")
    assert_equal [ [ 309.83, [ 1, 2, 3 ] ] ], check["listings"].map { |l| l.values_at("price", "seats") }
  end

  test "with two open seats, the pair view is the only look needed" do
    meta = read_page(our_quantity: 2)

    assert_equal [ "done", 12 ], meta.values_at("status", "event_total_listings")
    assert_nil meta["quantity_check"]
  end

  test "a page that opens at another quantity is set back to 2 before pricing" do
    meta = read_page("?start=3")

    assert_equal [ "done", 12, 11 ], meta.values_at("status", "event_total_listings", "kept")
    assert_equal 3, meta.dig("quantity_check", "quantity")
  end

  test "a list that stops loading short of the results count is stalled, not complete" do
    meta = read_page("?stall=4")

    assert_equal [ "stalled", 4, 12 ], meta.values_at("status", "read", "event_total_listings")
    assert_nil meta["our_row"]
  end
end
