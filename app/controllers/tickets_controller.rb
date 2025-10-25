class TicketsController < ApplicationController
  def create
    @game = Game.find(params[:game_id])
    @ticket = @game.tickets.build(ticket_params)

    if @ticket.save
      redirect_to @game, notice: "Ticket sale recorded successfully!"
    else
      flash[:alert] = @ticket.errors.full_messages.join(", ")
      redirect_to @game
    end
  end

  def destroy
    @ticket = Ticket.find(params[:id])
    @game = @ticket.game

    @ticket.destroy
    redirect_to @game, notice: "Ticket sale removed"
  end

  private

  def ticket_params
    params.require(:ticket).permit(:section, :row, :seat_number, :sale_price, :buyer_id, :notes)
  end
end
