require "test_helper"

class StatusChipHelperTest < ActionView::TestCase
  include IconHelper

  setup do
    @today = Date.new(2026, 11, 16)
    @game = seasons(:current).games.create!(game_number: 50, game_date: @today + 2, opponent: teams(:rockets),
                                            cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
  end

  def chip_text(html)
    Nokogiri::HTML.fragment(html).text.squish
  end

  test "countdown labels the coming week and nothing else" do
    assert_equal "Today", chip_text(countdown_chip(@game, today: @today + 2))
    assert_equal "Tomorrow", chip_text(countdown_chip(@game, today: @today + 1))
    assert_equal "In 2 days", chip_text(countdown_chip(@game, today: @today))
    assert_nil countdown_chip(@game, today: @today - 6)
    assert_nil countdown_chip(@game, today: @today + 3)
  end

  test "countdown is amber when seats are open within three days, never red" do
    assert_includes countdown_chip(@game, today: @today), "text-warning"
    assert_includes countdown_chip(@game, today: @today - 4), "text-accent"
    3.times { |i| @game.tickets.create!(seat_number: i + 1, sale_price: 150) }
    assert_includes countdown_chip(@game.reload, today: @today), "text-content-dim"
    assert_not_includes countdown_chip(@game, today: @today), "text-negative"
  end

  test "inventory chip says what's left to sell" do
    assert_equal "3 to sell", chip_text(inventory_chip(@game, today: @today))
    @game.tickets.create!(seat_number: 1, sale_price: 150)
    assert_equal "2 left", chip_text(inventory_chip(@game.reload, today: @today))
    assert_equal "2 unsold", chip_text(inventory_chip(@game, today: @today + 5))
    @game.tickets.create!(seat_number: 2, sale_price: 150)
    @game.tickets.create!(seat_number: 3, sale_price: 150)
    assert_equal "Sold out", chip_text(inventory_chip(@game.reload, today: @today))
  end

  test "game_when adds the tipoff when it's known" do
    assert_equal "Wed, Nov 18", game_when(@game)
    @game.tipoff_at = Time.zone.local(2026, 11, 18, 19, 0)
    assert_equal "Wed, Nov 18 · 7:00 PM", game_when(@game)
  end

  test "status_chip escapes its label" do
    html = status_chip("<b>x</b>", tone: :positive)
    assert_includes html, "&lt;b&gt;"
    assert_raises(KeyError) { status_chip("x", tone: :purple) }
  end
end
