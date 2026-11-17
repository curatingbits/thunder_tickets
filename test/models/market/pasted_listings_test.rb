require "test_helper"

class Market::PastedListingsTest < ActiveSupport::TestCase
  test "reads listings copied from a Ticketmaster page, across line breaks" do
    text = <<~TEXT
      Sec 101 • Row EE
      Verified Resale Ticket
      $297.68
      Sec 120 • Row MM
      Standard Admission
      $146.95
      Sec 102 • Row L Verified Resale Ticket $1,136.08
    TEXT

    listings = Market::PastedListings.parse(text)

    assert_equal [ [ "101", "EE", 297.68, "verified_resale" ], [ "120", "MM", 146.95, "standard_admission" ],
                   [ "102", "L", 1136.08, "verified_resale" ] ],
                 listings.map { |l| l.values_at(:section, :row, :price, :ticket_type) }
    assert_equal [ 1, 2, 3 ], listings.map { |l| l[:position] }
  end

  test "reads section,row,price lines" do
    listings = Market::PastedListings.parse("101,ee,298.08\n120\tGG\t$303\nnot a listing")
    assert_equal [ [ "101", "EE", 298.08 ], [ "120", "GG", 303.0 ] ], listings.map { |l| l.values_at(:section, :row, :price) }
  end

  test "a label with no price is skipped" do
    assert_empty Market::PastedListings.parse("Sec 101 • Row EE\nVerified Resale Ticket")
  end
end
