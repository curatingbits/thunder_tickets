class DashboardController < ApplicationController
  def index
    @season = current_season
    return redirect_to login_path, alert: "No current season found" unless @season

    # Core metrics
    @metrics = @season.dashboard_metrics
    @break_even_status = @season.break_even_status
    @break_even_metrics = @season.break_even_metrics

    # Performance indicators
    @best_game = @season.best_performing_game
    @worst_game = @season.worst_performing_game

    # Upcoming games
    @upcoming_games = @season.games.upcoming.limit(5)

    # Recent sales with preloaded associations
    @recent_sales = Ticket.joins(:game)
                          .includes(game: :opponent)
                          .where(games: { season_id: @season.id })
                          .order(sold_at: :desc)
                          .limit(10)

    # Chart data: Monthly revenue trend
    @monthly_revenue = @season.games
                              .joins(:tickets)
                              .group("strftime('%Y-%m', games.game_date)")
                              .sum("tickets.sale_price")

    # Chart data: Profit by game (for profit distribution chart)
    @game_profits = @season.games.includes(:opponent, :tickets).map do |game|
      {
        opponent: game.opponent.abbreviation,
        profit: game.profit_loss,
        revenue: game.total_revenue,
        cost: game.total_cost,
        tickets_sold: game.tickets_sold_count,
        date: game.game_date
      }
    end.sort_by { |g| g[:date] }

    # Games by status counts
    @games_fully_sold = @season.games.select(&:fully_sold?).count
    @games_partially_sold = @season.games.select(&:partially_sold?).count
    @games_unsold = @season.games.select(&:unsold?).count
  end
end
