# The Pricing tab: what each upcoming game's seats are worth and what to
# list them at. Advisory only; nothing here changes a listing.
class PricingController < ApplicationController
  # It opens on the games with seats still unsold. Sold and transferred
  # games show only under "All".
  DEFAULT_FILTER = "unsold"
  FILTERS = {
    "unsold" => ->(row) { row.status.open_seats.any? },
    "action" => ->(row) { row.needs_action? },
    "overpriced" => ->(row) { row.assessment == "overpriced" },
    "underpriced" => ->(row) { row.assessment == "underpriced" },
    "not_listed" => ->(row) { row.assessment == "not_listed" },
    "verify" => ->(row) { row.assessment == "needs_verification" },
    "all" => ->(_row) { true }
  }.freeze
  SEAT_MAP_FRAME = "seat_map_listings"

  def index
    @season = current_season
    return redirect_to root_path, alert: "No current season" unless @season

    @board = Market::Board.new(@season)
    @filter = FILTERS.key?(params[:filter]) ? params[:filter] : DEFAULT_FILTER
    @map = map_on?
    load_seat_map if @map
    return render partial: "pricing/seat_map_listings" if @map && turbo_frame_request_id == SEAT_MAP_FRAME

    @value = Market::InventoryValue.from(@board.rows)
    @counts = @board.rows.filter_map(&:assessment).tally
    @rows = @board.rows.select { |row| row.seats_to_sell.positive? || row.snapshot }.select(&FILTERS.fetch(@filter))
  end

  private

  # The board's filter, carried into the seat map's links (the default stays out of the address).
  def map_filter = (@filter unless @filter == DEFAULT_FILTER)
  helper_method :map_filter

  # The 3D seat map switch: ?map=on|off, remembered on this device. A
  # prefetch (Turbo on hover) never changes what's remembered.
  def map_on?
    if %w[on off].include?(params[:map]) && request.headers["X-Sec-Purpose"] != "prefetch"
      cookies.permanent[:pricing_map] = { value: params[:map], httponly: true, same_site: :lax }
    end
    (params[:map].presence_in(%w[on off]) || cookies[:pricing_map]) == "on"
  end

  # Any upcoming game with market data can be mapped, sold or not. Opens on
  # ?game_id= or the soonest.
  def load_seat_map
    rows = @board.rows.select(&:snapshot)
    @map_games = rows.map(&:game)
    row = rows.find { |r| r.game.id == params[:game_id].to_i } || rows.first
    return unless row

    @map_game = row.game
    @seat_map = Market::SeatMap.new(row.snapshot, settings: @board.settings, our_all_in: row.our_all_in)
  end
end
