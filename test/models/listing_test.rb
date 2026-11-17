require "test_helper"

class ListingTest < ActiveSupport::TestCase
  setup do
    @game = games(:current_future)
  end

  def build(attrs = {})
    @game.listings.build({ seat_numbers: [ 1, 2 ], platform: "ticketmaster", ask_price: 200 }.merge(attrs))
  end

  test "a listing needs seats, a platform and a positive price" do
    assert build.valid?
    assert_not build(seat_numbers: []).valid?
    assert_not build(platform: "craigslist").valid?
    assert_not build(ask_price: nil).valid?
    assert_not build(ask_price: 0).valid?
  end

  test "a hold needs only seats" do
    assert @game.listings.build(kind: "hold", seat_numbers: [ 3 ]).valid?
  end

  test "seats must exist, be unsold and not be on another active listing" do
    assert_not build(seat_numbers: [ 4 ]).valid?

    @game.tickets.create!(seat_number: 1, sale_price: 150)
    listing = build
    assert_not listing.valid?
    assert_match(/already sold/, listing.errors.full_messages.to_sentence)

    build(seat_numbers: [ 2 ]).save!
    overlapping = build(seat_numbers: [ 2, 3 ])
    assert_not overlapping.valid?
    assert_match(/another listing or hold/, overlapping.errors.full_messages.to_sentence)
  end

  test "seat numbers from a form are cleaned up" do
    listing = build(seat_numbers: [ "", "2", "1", "2" ])
    listing.valid?
    assert_equal [ 1, 2 ], listing.seat_numbers
  end

  test "repricing a partly sold listing doesn't trip the seat check" do
    listing = build(seat_numbers: [ 1, 2 ])
    listing.save!
    @game.tickets.create!(seat_number: 1, sale_price: 150)

    assert listing.reload.update(ask_price: 180)
    assert_equal [ 2 ], listing.open_seats
  end
end

class ListingEventTest < ActiveSupport::TestCase
  test "events are append-only" do
    event = ListingEvent.create!(game: games(:current_future), action: "verified_unlisted")

    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(note: "changed") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy }
  end

  test "only known actions" do
    assert_not ListingEvent.new(game: games(:current_future), action: "guessed").valid?
  end
end
