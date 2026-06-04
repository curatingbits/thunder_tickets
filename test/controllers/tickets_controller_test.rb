require "test_helper"

class TicketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    @game = games(:current_past) # 2 of 3 seats sold, seat 3 open
  end

  test "should create a ticket sale" do
    assert_difference "Ticket.count", 1 do
      post game_tickets_path(@game), params: { ticket: { seat_number: 3, sale_price: 110 } }
    end
    assert_redirected_to game_path(@game)
  end

  test "should destroy a ticket sale" do
    ticket = tickets(:cur_past_1)
    assert_difference "Ticket.count", -1 do
      delete game_ticket_path(@game, ticket)
    end
    assert_redirected_to game_path(@game)
  end
end
