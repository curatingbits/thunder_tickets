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

  def index
    @season = current_season
    return redirect_to root_path, alert: "No current season" unless @season

    @board = Market::Board.new(@season)
    @value = Market::InventoryValue.from(@board.rows)
    @counts = @board.rows.filter_map(&:assessment).tally
    @filter = FILTERS.key?(params[:filter]) ? params[:filter] : DEFAULT_FILTER
    @rows = @board.rows.select { |row| row.seats_to_sell.positive? || row.snapshot }.select(&FILTERS.fetch(@filter))
  end
end
