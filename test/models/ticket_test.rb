require "test_helper"

class TicketTest < ActiveSupport::TestCase
  setup do
    @ticket = tickets(:cur_past_1)
    @evening_sale = Time.zone.parse("2026-11-10 21:15")
    @ticket.update!(sold_at: @evening_sale)
  end

  test "sold_on is the date of sold_at" do
    assert_equal Date.new(2026, 11, 10), @ticket.sold_on
  end

  test "sold_on= moves the sale to a new date but keeps its time of day" do
    @ticket.sold_on = "2026-11-08"

    assert_equal Time.zone.parse("2026-11-08 21:15"), @ticket.sold_at
  end

  test "submitting the date a sale already has leaves sold_at untouched" do
    @ticket.update!(sold_on: "2026-11-10", sale_price: 140)

    assert_equal @evening_sale, @ticket.reload.sold_at
  end

  test "blank and unparseable dates are ignored" do
    @ticket.sold_on = ""
    @ticket.sold_on = "not a date"

    assert_equal @evening_sale, @ticket.sold_at
  end
end

class TicketListingTest < ActiveSupport::TestCase
  setup do
    @game = games(:current_future)
    @listing = @game.listings.create!(seat_numbers: [ 1, 2 ], platform: "ticketmaster", ask_price: 210, verified_at: Time.current)
  end

  test "a sale of a listed seat links the listing and keeps its list price" do
    ticket = @game.tickets.create!(seat_number: 1, sale_price: 185.40)

    assert_equal @listing, ticket.listing
    assert_equal BigDecimal("210"), ticket.list_price_at_sale
  end

  test "an all-in asking price isn't stored as a list price" do
    @listing.update!(ask_price_basis: "buyer_all_in")
    assert_nil @game.tickets.create!(seat_number: 1, sale_price: 185.40).list_price_at_sale
  end

  test "Ticketmaster sales count as delivered when they sell" do
    ticket = @game.tickets.create!(seat_number: 1, sale_price: 185.40)
    assert_equal ticket.sold_at, ticket.transferred_at

    private_sale = @game.tickets.create!(seat_number: 3, sale_price: 200)
    assert_nil private_sale.transferred_at
  end

  test "the listing ends once all its seats have sold" do
    @game.tickets.create!(seat_number: 1, sale_price: 185.40)
    assert @listing.reload.active?

    @game.tickets.create!(seat_number: 2, sale_price: 185.40)
    @listing.reload
    assert_equal "ended", @listing.status
    assert_equal "sold", @listing.end_reason
    assert_equal [ "ended" ], @listing.events.pluck(:action)
  end
end
