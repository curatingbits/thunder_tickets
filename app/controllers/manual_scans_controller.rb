# The fallback when automated research can't run: paste a game's listings by
# hand. They go through the same engine, marked as manual (lower confidence).
class ManualScansController < ApplicationController
  before_action :set_game

  def new
  end

  def create
    listings = Market::PastedListings.parse(params[:listings_text])
    if listings.empty?
      flash.now[:alert] = "No listings found. Paste the listing text from Ticketmaster, or section,row,price lines."
      return render :new, status: :unprocessable_entity
    end

    now = Time.current
    run = ImportRun.create!(kind: "market_research", source: "manual", key: "manual-#{@game.id}-#{SecureRandom.hex(4)}",
                            status: "completed", started_at: now, finished_at: now, user: current_user,
                            params: { "game_id" => @game.id })
    Market::ScanIngest.new(run: run, game: @game, manual: true, now: now,
                           payload: { listings: listings, quantity_filter: 2, scroll_complete: false, captured_at: now.iso8601 }).call
    redirect_to @game, notice: "Added #{listings.size} listings."
  rescue Market::ScanIngest::Invalid => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  private

  def set_game
    @game = Game.find(params[:game_id])
  end
end
