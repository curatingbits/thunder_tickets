# Patterns in the market data: what moves the value of our seats. Advisory;
# asking prices, not sales.
class InsightsController < ApplicationController
  def show
    @season = current_season
    return redirect_to root_path, alert: "No current season" unless @season

    @insights = Market::Insights.new(@season)
  end
end
