require "application_system_test_case"

# The Ticketmaster page reader (automation/skills/ticketmaster-pricing/
# extract_listings.js) against a stand-in page with the parts it relies on:
# a list that loads as it scrolls, a quantity menu, and Row DD cards that
# open a "Ticket Selection" panel saying which seats you'd get.
class ExtractListingsTest < ApplicationSystemTestCase
  READER = Rails.root.join("automation/skills/ticketmaster-pricing/extract_listings.js").read
  PAGE = Rails.root.join("test/fixtures/files/tm_event_page.html")

  NEAR_DD = %w[AA BB CC DD EE FF GG].freeze

  def read_page(query = "", our_quantity: 3, seat_reads_max: nil, drawn: true)
    visit "file://#{PAGE}#{query}"
    page.execute_script("window.__madrSections = ['101', '102', '120', '119']; " \
                        "window.__madrSeatRows = #{%w[101 102 120].index_with { NEAR_DD }.to_json}; " \
                        "window.__madrOurs = { section: '101', row: 'DD', quantity: #{our_quantity} };")
    page.execute_script("window.__madrSeatReadsMax = #{seat_reads_max}") if seat_reads_max
    # A tab behind another tab: Chromium draws no frames for it.
    page.execute_script("window.requestAnimationFrame = () => 0") unless drawn
    # Assigned, not returned: the file opens with comments, and "return" + a
    # comment line would return before the code.
    page.execute_script("window.__readerStarted = #{READER}")
    assert_equal "started", page.evaluate_script("window.__readerStarted")
    Timeout.timeout(90) { sleep 0.5 until page.evaluate_script("window.__madr.status") != "running" }
    JSON.parse(page.evaluate_script("window.__madrMeta()"))
  end

  test "prices at 2 tickets, and finds our 3-seat listing by looking again at 3" do
    meta = read_page

    assert_equal [ "done", true, 15, 14 ], meta.values_at("status", "scroll_complete", "event_total_listings", "kept")
    assert_equal [ { "price" => 151.88, "seats" => [ 6, 7 ] } ], meta["our_row"], "someone else's pair shows at 2"
    check = meta["quantity_check"]
    assert_equal [ 3, true ], check.values_at("quantity", "complete")
    assert_equal [ [ 309.83, [ 1, 2, 3 ] ] ], check["listings"].map { |l| l.values_at("price", "seats") }
    assert_match "[Seats 1-3]", check["listings"].first["raw_label"]

    rows = JSON.parse(page.evaluate_script("window.__madrChunk(0, 20)"))
    assert_equal [ 6, 7 ], rows.find { |r| r[2] == "DD" }[6]
    assert_nil rows.find { |r| r[2] == "K" }[6], "row K is too far from DD to be opened"
    assert_not page.evaluate_script("!!window.reserved"), "never presses Reserve Tickets"
    assert_no_selector "#panel"
  end

  test "opens the listings in rows near ours for their seats, and keeps section 119 for context" do
    meta = read_page
    rows = JSON.parse(page.evaluate_script("window.__madrChunk(0, 20)")).index_by { |r| r.values_at(1, 2) }

    assert_equal [ 4, 5 ], rows[%w[120 CC]][6]
    assert_equal [ 8, 9 ], rows[%w[101 BB]][6]
    assert_equal [ 10, 11 ], rows[%w[101 EE]][6]
    assert_match "[Seats 4-5]", rows[%w[120 CC]][5]
    assert_nil rows[%w[102 JJ]][6], "rows far from DD are only read from the list"
    assert_nil rows[%w[119 EE]][6], "119 is context: kept, never opened"
    assert_equal [ 2, 3 ], rows[%w[120 EE]][6]
    assert_equal [ 5, 0 ], meta.values_at("seat_reads", "seat_reads_capped")
    assert_not page.evaluate_script("!!window.reserved"), "never presses Reserve Tickets"
  end

  test "stops opening rows near ours at the cap, but always reads our row" do
    meta = read_page(seat_reads_max: 1)
    rows = JSON.parse(page.evaluate_script("window.__madrChunk(0, 20)"))

    assert_equal [ 1, 4 ], meta.values_at("seat_reads", "seat_reads_capped")
    assert_equal [ 6, 7 ], rows.find { |r| r[1] == "101" && r[2] == "DD" }[6]
    assert_equal 1, rows.count { |r| r[6] && r.values_at(1, 2) != %w[101 DD] }, "one other row read before the cap"
  end

  test "finds the quantity button by its text when it has no aria-label" do
    meta = read_page("?label=text&start=3")

    assert_equal [ "done", 15, 14 ], meta.values_at("status", "event_total_listings", "kept")
    check = meta["quantity_check"]
    assert_equal [ 3, true ], check.values_at("quantity", "complete")
    assert_equal [ [ 309.83, [ 1, 2, 3 ] ] ], check["listings"].map { |l| l.values_at("price", "seats") }
  end

  test "with two open seats, the pair view is the only look needed" do
    meta = read_page(our_quantity: 2)

    assert_equal [ "done", 15 ], meta.values_at("status", "event_total_listings")
    assert_nil meta["quantity_check"]
  end

  test "a page that opens at another quantity is set back to 2 before pricing" do
    meta = read_page("?start=3")

    assert_equal [ "done", 15, 14 ], meta.values_at("status", "event_total_listings", "kept")
    assert_equal 3, meta.dig("quantity_check", "quantity")
  end

  test "a list that stops loading short of the results count is stalled, not complete" do
    meta = read_page("?stall=4")

    assert_equal [ "stalled", 4, 15 ], meta.values_at("status", "read", "event_total_listings")
    assert_operator meta["fps"], :>=, 20, "the page was being drawn, so the stall is Ticketmaster's"
    assert_nil meta["our_row"]
  end

  test "a tab Chromium isn't drawing stops before reading, as not drawing rather than a stall" do
    meta = read_page("?stall=4", drawn: false)

    assert_equal [ "not_drawing", 0 ], meta.values_at("status", "fps")
    assert_nil meta["read"], "nothing read: the list would stop after the first listings"
    assert_nil meta["our_row"]
    assert_not page.evaluate_script("!!window.reserved")
  end
end
