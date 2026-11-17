class TicketsController < ApplicationController
  before_action :set_game
  before_action :set_ticket, only: [ :edit, :update, :destroy, :transfer ]

  def create
    @ticket = @game.tickets.build(ticket_params)

    if @ticket.save
      redirect_to @game, notice: "Ticket sale recorded successfully!"
    else
      flash[:alert] = @ticket.errors.full_messages.join(", ")
      redirect_to @game
    end
  end

  def bulk_create
    available_seats = (1..@game.season.num_seats).to_a - @game.tickets.pluck(:seat_number)

    if available_seats.empty?
      redirect_to @game, alert: "No tickets available"
      return
    end

    total_amount = params[:total_amount].to_f
    price_per_ticket = (total_amount / available_seats.count).round(2)

    Ticket.transaction do
      available_seats.each do |seat|
        @game.tickets.create!(
          section: @game.season.seat_section,
          row: @game.season.seat_row,
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

  def edit
    load_form_options
  end

  def update
    if @ticket.update(ticket_params)
      redirect_to @game, notice: "Sale updated."
    else
      load_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @ticket.destroy
    redirect_to @game, notice: "Ticket sale removed"
  end

  # The buyer has the tickets (Ticketmaster resale does this on its own).
  def transfer
    @ticket.update!(transferred_at: Time.current) unless @ticket.transferred?
    redirect_back_or_to @game, notice: "Seat #{@ticket.seat_number} marked delivered."
  end

  private

  def set_game
    @game = Game.find(params[:game_id])
  end

  # Scoped through the game so a ticket can't be edited under another game's URL.
  def set_ticket
    @ticket = @game.tickets.find(params[:id])
  end

  def load_form_options
    # Open seats plus the one this sale already holds.
    taken = @game.tickets.where.not(id: @ticket.id).pluck(:seat_number)
    @seat_options = (1..@game.season.num_seats).to_a - taken
    @buyers = Buyer.by_name
  end

  def ticket_params
    params.require(:ticket).permit(:section, :row, :seat_number, :sale_price, :buyer_id, :notes, :sold_on, :payout_received_by)
  end
end
