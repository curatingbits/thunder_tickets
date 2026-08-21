class DashboardController < ApplicationController
  def index
    # viewed_season honours ?season_id= and remembers it for the session,
    # defaulting to the current season. is_current is never disturbed.
    @season = viewed_season
    return redirect_to login_path, alert: "No current season found" unless @season

    @seasons  = Season.order(year: :desc)
    @is_recap = @season.complete?
    # Scheduled but not underway — the overview zone shows a commitment
    # summary rather than -100% ROI and a row of zeroes.
    @not_started = @season.not_started?

    # Core metrics
    @metrics = @season.dashboard_metrics
    @break_even_status = @season.break_even_status
    @break_even_metrics = @season.break_even_metrics

    # Load games once with associations preloaded, then derive everything in
    # memory to avoid per-game N+1 queries.
    games = @season.games.includes(:opponent, :tickets).to_a

    # Performance indicators
    @best_game  = games.max_by(&:profit_loss)
    @worst_game = games.select { |g| g.tickets_sold_count.positive? }.min_by(&:profit_loss)

    # Upcoming games (empty for a completed season)
    @upcoming_games = @season.games.upcoming.includes(:opponent).limit(5)

    # Past games, most recent first (used for the recap "Final Results" list)
    @past_games = @season.games.past.includes(:opponent).limit(5) if @is_recap

    # Recent sales with preloaded associations
    @recent_sales = Ticket.joins(:game)
                          .includes(game: :opponent)
                          .where(games: { season_id: @season.id })
                          .order(sold_at: :desc)
                          .limit(10)

    # Chart data: cumulative revenue vs cost over the season timeline
    @monthly_financials = @season.monthly_financials

    # Chart data: profit by game (for profit distribution chart)
    @game_profits = games.map do |game|
      {
        opponent: game.opponent.abbreviation,
        profit: game.profit_loss,
        revenue: game.total_revenue,
        cost: game.total_cost,
        tickets_sold: game.tickets_sold_count,
        date: game.game_date
      }
    end.sort_by { |g| g[:date] }

    # Profit / ROI broken out by game type
    @game_type_breakdown = @season.profit_by_game_type

    # Games by status counts
    @games_fully_sold = games.count(&:fully_sold?)
    @games_partially_sold = games.count(&:partially_sold?)
    @games_unsold = games.count(&:unsold?)
  end
end
