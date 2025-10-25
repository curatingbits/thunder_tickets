class DashboardController < ApplicationController
  def index
    @season = current_season
    return redirect_to login_path, alert: "No current season found" unless @season

    @total_games = @season.games.count
    @games_with_sales = @season.games.joins(:tickets).distinct.count
    @total_cost = @season.total_cost
    @total_revenue = @season.total_revenue
    @total_profit = @season.total_profit
    @tickets_sold = @season.tickets_sold_count
    @total_tickets = @season.total_tickets_available
    @percentage_sold = @season.percentage_sold
    @on_track = @season.on_track_to_break_even?

    # Upcoming games
    @upcoming_games = @season.games.upcoming.limit(5)

    # Recent sales
    @recent_sales = Ticket.joins(:game)
                          .where(games: { season_id: @season.id })
                          .order(sold_at: :desc)
                          .limit(10)

    # Financial chart data
    @monthly_revenue = @season.games
                              .joins(:tickets)
                              .group("strftime('%Y-%m', games.game_date)")
                              .sum("tickets.sale_price")

    @game_profitability = @season.games
                                 .joins(:tickets)
                                 .group("games.opponent_id")
                                 .select("games.opponent_id, SUM(tickets.sale_price) - ((games.cost_per_ticket * #{@season.num_seats}) + games.parking_cost) as profit")
  end
end
