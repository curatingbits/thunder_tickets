# Records our listings and holds and every decision about them. Nothing here
# reaches Ticketmaster: a listing is what we say we asked, and "verify" means a
# person just checked it.
class ListingsController < ApplicationController
  before_action :set_game
  before_action :set_listing, only: [ :edit, :update, :verify, :close ]

  def new
    kind = params[:kind] == "hold" ? "hold" : "listing"
    @listing = @game.listings.build(kind: kind, platform: "ticketmaster", account_user: current_user,
                                    seat_numbers: unlisted_open_seats)
  end

  def create
    @listing = @game.listings.build(listing_params.merge(verified_at: Time.current, verified_by: current_user))
    Listing.transaction do
      @listing.save!
      @listing.events.create!(game: @game, user: current_user, action: @listing.hold? ? "held" : "listed",
                              price_after: @listing.ask_price, note: @listing.notes.presence, **recommendation)
    end
    redirect_to @game, notice: @listing.hold? ? "Seats held." : "Listing recorded at #{price(@listing.ask_price)}."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  # A person editing the listing has just looked at it, so it counts as
  # verified too.
  def update
    before = @listing.ask_price
    @listing.assign_attributes(listing_params.except(:kind).merge(verified_at: Time.current, verified_by: current_user))
    repriced = @listing.ask_price_changed?
    Listing.transaction do
      @listing.save!
      @listing.events.create!(game: @game, user: current_user, action: repriced ? "price_changed" : "verified",
                              price_before: before, price_after: @listing.ask_price, **recommendation)
    end
    redirect_to @game, notice: repriced ? "Price changed to #{price(@listing.ask_price)}." : "Listing updated."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  def verify
    Listing.transaction do
      @listing.update!(verified_at: Time.current, verified_by: current_user)
      @listing.events.create!(game: @game, user: current_user, action: "verified", price_after: @listing.ask_price)
    end
    redirect_back_or_to @game, notice: "Confirmed still listed."
  end

  # Taken down: that's also a confirmation the seats aren't listed.
  def close
    Listing.transaction do
      @listing.update!(status: "ended", end_reason: "delisted", ended_at: Time.current)
      @listing.events.create!(game: @game, user: current_user, action: "ended", price_before: @listing.ask_price,
                              note: @listing.hold? ? "Hold released" : "Taken down")
      ListingEvent.create!(game: @game, user: current_user, action: "verified_unlisted") if @listing.listing?
    end
    redirect_back_or_to @game, notice: @listing.hold? ? "Hold released." : "Listing taken down."
  end

  # "Nothing is listed for this game": ends any listing we thought was up.
  def verify_unlisted
    Listing.transaction do
      @game.listings.active.for_sale.each do |listing|
        listing.update!(status: "ended", end_reason: "delisted", ended_at: Time.current)
        listing.events.create!(game: @game, user: current_user, action: "ended", price_before: listing.ask_price,
                               note: "Confirmed not listed")
      end
      ListingEvent.create!(game: @game, user: current_user, action: "verified_unlisted")
    end
    redirect_back_or_to @game, notice: "Confirmed not listed."
  end

  private

  def set_game
    @game = Game.find(params[:game_id])
  end

  def set_listing
    @listing = @game.listings.find(params[:id])
  end

  # What the app recommended when the decision was made, so the history can
  # later show whether following it paid off.
  def recommendation
    snapshot = @game.market_snapshots.valid.latest_first.first
    return {} unless snapshot&.recommended_list_price

    { market_snapshot: snapshot, recommended_strategy: snapshot.recommended_strategy,
      recommended_list_price: snapshot.recommended_list_price }
  end

  def unlisted_open_seats
    open = (1..@game.season.num_seats).to_a - @game.tickets.pluck(:seat_number)
    open - @game.listings.active.flat_map(&:seat_numbers)
  end

  def listing_params
    params.require(:listing).permit(:kind, :platform, :account_user_id, :ask_price, :ask_price_basis, :notes,
                                    seat_numbers: [])
  end

  def price(amount)
    ActiveSupport::NumberHelper.number_to_currency(amount)
  end
end
