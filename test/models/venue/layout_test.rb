require "test_helper"

class Venue::LayoutTest < ActiveSupport::TestCase
  setup { @layout = Venue::Layout.paycom }

  test "the four home-end sections, left to right from the court" do
    assert_equal %w[119 120 101 102], @layout.section_ids
    assert_equal %w[corner baseline baseline corner], @layout.sections.map(&:shape)
    assert_equal %w[left left right right], @layout.sections.map(&:side)
  end

  test "101 and 120 as counted on Ticketmaster's map" do
    assert_equal 7, @layout.row("101", "DD").seats, "our row: 7 seats, seat 1 on the aisle"
    assert_equal 6, @layout.row("120", "AA").seats
    assert_equal [ 10, 1 ], @layout.row("101", "T").deconstruct.values_at(2, 3), "101 T: no seat at the aisle end"
    assert_nil @layout.row("120", "S"), "120 has row SA in S's place, and no row T"
    assert_nil @layout.row("120", "T")
    assert_equal @layout.row("101", "S").depth, @layout.row("120", "SA").depth
    assert_equal [ 12, 3 ], @layout.row("120", "FL1").deconstruct.values_at(2, 3)
    assert_nil @layout.row("119", "FL1"), "the corners have no floor rows"
  end

  test "rows go front to back in Ticketmaster's order" do
    depths = @layout.section("101").rows.map(&:depth)
    assert_equal depths.sort, depths
    assert_equal %w[FL1 FL2 FL3 AA], @layout.section("101").rows.first(4).map(&:name)
    assert_equal "U", @layout.section("101").rows.last.name
  end

  test "the client gets compact rows and which sections are estimates" do
    client = @layout.to_client
    corner = client[:sections].find { |s| s[:id] == "119" }

    assert corner[:estimated]
    assert_not client[:sections].find { |s| s[:id] == "101" }[:estimated]
    assert_includes client[:sections].find { |s| s[:id] == "101" }[:rows], [ "DD", 6, 7, 0 ]
  end

  test "a mistake in the file fails loudly" do
    spec = { "name" => "x", "sections" => { "101" => { "shape" => "baseline", "side" => "right", "source" => "x", "rows" => { "ZZ" => 4 } } } }
    assert_raises(Venue::Layout::Invalid) { Venue::Layout.new(spec) }

    spec["sections"]["101"]["rows"] = { "AA" => 0 }
    assert_raises(Venue::Layout::Invalid) { Venue::Layout.new(spec) }
  end
end
