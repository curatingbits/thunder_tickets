require "test_helper"

class Listings::GameStatusTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.local(2026, 11, 16, 12)
    @game = seasons(:current).games.create!(game_number: 70, game_date: Date.new(2026, 11, 25), opponent: teams(:rockets),
                                            cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
  end

  def status(game = @game)
    Listings::GameStatus.for(game.reload, now: @now)
  end

  def sell(*seats, delivered: false)
    seats.each { |seat| @game.tickets.create!(seat_number: seat, sale_price: 150, transferred_at: (@now if delivered)) }
  end

  def list(seats, verified_at: @now - 1.day, price: 210)
    @game.listings.create!(seat_numbers: seats, platform: "ticketmaster", ask_price: price, verified_at: verified_at)
  end

  test "with nothing recorded the answer is needs verification, never not listed" do
    result = status
    assert_equal :needs_verification, result.status
    assert_equal [ 1, 2, 3 ], result.unlisted_seats
  end

  test "a freshly verified listing covering every open seat is listed" do
    list([ 1, 2, 3 ])
    result = status
    assert_equal :listed, result.status
    assert_equal [ BigDecimal("210") ], result.ask_prices
  end

  test "a listing nobody has checked for over a week needs verification" do
    list([ 1, 2, 3 ], verified_at: @now - 8.days)
    assert_equal :needs_verification, status.status
  end

  test "a listing covering only some open seats needs verification" do
    list([ 1, 2 ])
    assert_equal :needs_verification, status.status
  end

  test "a recent not-listed confirmation means not listed" do
    ListingEvent.create!(game: @game, action: "verified_unlisted", occurred_at: @now - 2.days)
    assert_equal :not_listed, status.status
  end

  test "a stale or superseded not-listed confirmation doesn't count" do
    ListingEvent.create!(game: @game, action: "verified_unlisted", occurred_at: @now - 9.days)
    assert_equal :needs_verification, status.status

    ListingEvent.create!(game: @game, action: "verified_unlisted", occurred_at: @now - 3.days)
    ListingEvent.create!(game: @game, action: "listed", occurred_at: @now - 2.days)
    assert_equal :needs_verification, status.status
  end

  test "some seats sold and the rest listed or confirmed unlisted is partially sold" do
    sell(1)
    list([ 2, 3 ])
    assert_equal :partially_sold, status.status

    @game.listings.update_all(status: "ended")
    ListingEvent.create!(game: @game, action: "verified_unlisted", occurred_at: @now - 1.hour)
    result = status
    assert_equal :partially_sold, result.status
    assert_equal [ 2, 3 ], result.unlisted_seats
  end

  test "every open seat held is reserved" do
    sell(1)
    @game.listings.create!(kind: "hold", seat_numbers: [ 2, 3 ])
    assert_equal :reserved, status.status
  end

  test "all seats sold is sold until every ticket is delivered" do
    sell(1, 2, 3)
    result = status
    assert_equal :sold, result.status
    assert_equal 3, result.untransferred_count

    @game.tickets.update_all(transferred_at: @now)
    assert_equal :transferred, status.status
  end

  test "open seats after the game are unsold, whatever was recorded" do
    @game.update!(game_date: Date.new(2026, 11, 10))
    assert_equal :unsold, status.status
  end
end
