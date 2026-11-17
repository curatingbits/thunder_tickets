require "application_system_test_case"

# The Ticketmaster page reader (automation/skills/ticketmaster-pricing/
# extract_listings.js) against a stand-in page with the parts it relies on:
# a list that loads as it scrolls, and Row DD cards that open a "Ticket
# Selection" panel saying which seats you'd get.
class ExtractListingsTest < ApplicationSystemTestCase
  READER = Rails.root.join("automation/skills/ticketmaster-pricing/extract_listings.js").read
  PAGE = Rails.root.join("test/fixtures/files/tm_event_page.html")

  def read_page(query = "")
    visit "file://#{PAGE}#{query}"
    page.execute_script("window.__madrSections = ['101', '102', '120']; window.__madrOurs = { section: '101', row: 'DD' };")
    # Assigned, not returned: the file opens with comments, and "return" + a
    # comment line would return before the code.
    page.execute_script("window.__readerStarted = #{READER}")
    assert_equal "started", page.evaluate_script("window.__readerStarted")
    Timeout.timeout(60) { sleep 0.5 until page.evaluate_script("window.__madr.status") != "running" }
    JSON.parse(page.evaluate_script("window.__madrMeta()"))
  end

  test "reads every listing, and the seat numbers of each Row DD listing" do
    meta = read_page

    assert_equal [ "done", true, 12, 11 ], meta.values_at("status", "scroll_complete", "event_total_listings", "kept")
    assert_equal [ { "price" => 151.88, "seats" => [ 6, 7 ] }, { "price" => 194.4, "seats" => [ 1, 2 ] } ], meta["our_row"]
    rows = JSON.parse(page.evaluate_script("window.__madrChunk(0, 20)"))
    ours = rows.find { |r| r[2] == "DD" && r[3] == 194.4 }
    assert_equal [ 1, 2 ], ours[6]
    assert_match "[Seats 1-2]", ours[5]
    assert_nil rows.find { |r| r[2] == "K" }[6], "seats are read only in our row"
    assert_not page.evaluate_script("!!window.reserved"), "never presses Reserve Tickets"
    assert_no_selector "#panel"
  end

  test "a list that stops loading short of the results count is stalled, not complete" do
    meta = read_page("?stall=4")

    assert_equal [ "stalled", 4, 12 ], meta.values_at("status", "read", "event_total_listings")
    assert_nil meta["our_row"]
  end
end
