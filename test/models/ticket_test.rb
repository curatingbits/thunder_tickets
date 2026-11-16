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
