# The Pricing tab: what each upcoming game's seats are worth and what to
# list them at. Advisory only; nothing here changes a listing.
class PricingController < ApplicationController
  FILTERS = {
    "action" => ->(row) { row.needs_action? },
    "overpriced" => ->(row) { row.assessment == "overpriced" },
    "underpriced" => ->(row) { row.assessment == "underpriced" },
    "not_listed" => ->(row) { row.assessment == "not_listed" },
    "verify" => ->(row) { row.assessment == "needs_verification" }
  }.freeze

  def index
    @season = current_season
    return redirect_to root_path, alert: "No current season" unless @season

    @board = Market::Board.new(@season)
    @value = Market::InventoryValue.from(@board.rows)
    @counts = @board.rows.filter_map(&:assessment).tally
    @rows = @board.rows.select { |row| row.seats_to_sell.positive? || row.snapshot }
    @rows = @rows.select(&FILTERS[params[:filter]]) if FILTERS.key?(params[:filter])
  end
end
