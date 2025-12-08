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

  def bulk_create
    @game = Game.find(params[:game_id])
    available_seats = (1..current_season.num_seats).to_a - @game.tickets.pluck(:seat_number)

    if available_seats.empty?
      redirect_to @game, alert: "No tickets available"
      return
    end

    total_amount = params[:total_amount].to_f
    price_per_ticket = (total_amount / available_seats.count).round(2)

    Ticket.transaction do
      available_seats.each do |seat|
        @game.tickets.create!(
          section: "101",
          row: "DD",
          seat_number: seat,
          sale_price: price_per_ticket,
          buyer_id: params[:buyer_id].presence,
          notes: params[:notes].presence
        )
      end
    end

    redirect_to @game, notice: "#{available_seats.count} tickets recorded at $#{price_per_ticket} each"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @game, alert: e.message
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
