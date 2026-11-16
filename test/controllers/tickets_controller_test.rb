require "test_helper"

class TicketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    @game = games(:current_past) # 2 of 3 seats sold, seat 3 open
    @ticket = tickets(:cur_past_1) # seat 1, $130, buyer john
  end

  test "should create a ticket sale" do
    assert_difference "Ticket.count", 1 do
      post game_tickets_path(@game), params: { ticket: { seat_number: 3, sale_price: 110 } }
    end
    assert_redirected_to game_path(@game)
  end

  test "should destroy a ticket sale" do
    assert_difference "Ticket.count", -1 do
      delete game_ticket_path(@game, @ticket)
    end
    assert_redirected_to game_path(@game)
  end

  # --- bulk ------------------------------------------------------------

  test "bulk sale fills the open seats" do
    assert_difference "Ticket.count", 1 do
      post bulk_create_game_tickets_path(@game), params: { total_amount: 150 }
    end
    assert_redirected_to game_path(@game)
    assert_equal 150, @game.tickets.find_by(seat_number: 3).sale_price
  end

  test "bulk sale uses the game's own season seat count" do
    # past_playoff is in a 2-seat season with seat 1 sold. Only seat 2 is
    # open, even though the current season holds 3 seats.
    game = games(:past_playoff)

    assert_difference "Ticket.count", 1 do
      post bulk_create_game_tickets_path(game), params: { total_amount: 200 }
    end
    assert_equal [ 1, 2 ], game.tickets.order(:seat_number).pluck(:seat_number)
  end

  # --- edit / update ---------------------------------------------------

  test "should get edit" do
    get edit_game_ticket_path(@game, @ticket)
    assert_response :success

    # Its own seat and the open seat are offered; the other sold seat is not.
    assert_select "select[name='ticket[seat_number]'] option", count: 2
    assert_select "select[name='ticket[seat_number]'] option[selected][value='1']"
    assert_select "select[name='ticket[buyer_id]'] option[selected][value='#{buyers(:john).id}']"
  end

  test "should update a sale" do
    patch game_ticket_path(@game, @ticket),
          params: { ticket: { sale_price: 175, notes: "Paid via Venmo", buyer_id: "" } }

    assert_redirected_to game_path(@game)
    @ticket.reload
    assert_equal 175, @ticket.sale_price
    assert_equal "Paid via Venmo", @ticket.notes
    assert_nil @ticket.buyer
  end

  test "update can move a sale to an open seat" do
    patch game_ticket_path(@game, @ticket), params: { ticket: { seat_number: 3 } }

    assert_redirected_to game_path(@game)
    assert_equal 3, @ticket.reload.seat_number
  end

  test "update can change the sale date" do
    patch game_ticket_path(@game, @ticket), params: { ticket: { sold_on: "2026-11-01" } }

    assert_redirected_to game_path(@game)
    assert_equal Date.new(2026, 11, 1), @ticket.reload.sold_on
  end

  test "update rejects a seat that's already sold" do
    patch game_ticket_path(@game, @ticket), params: { ticket: { seat_number: 2 } }

    assert_response :unprocessable_entity
    assert_equal 1, @ticket.reload.seat_number
  end

  test "update rejects a zero price" do
    patch game_ticket_path(@game, @ticket), params: { ticket: { sale_price: 0 } }

    assert_response :unprocessable_entity
    assert_equal 130, @ticket.reload.sale_price
  end

  test "a ticket can't be reached through another game's URL" do
    other_game = games(:current_future)

    get edit_game_ticket_path(other_game, @ticket)
    assert_response :not_found

    patch game_ticket_path(other_game, @ticket), params: { ticket: { sale_price: 1 } }
    assert_response :not_found
    assert_equal 130, @ticket.reload.sale_price
  end
end
