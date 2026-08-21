class Season < ApplicationRecord
  has_many :games, dependent: :destroy

  validates :year, presence: true, uniqueness: true
  validates :num_seats, presence: true, numericality: { greater_than: 0 }
  # seat_section is optional, but required for Ticketmaster API pricing features

  scope :current, -> { where(is_current: true).first }

  def total_cost
    games.sum { |g| (g.cost_per_ticket * num_seats) + g.parking_cost }
  end

  def total_revenue
    games.joins(:tickets).sum("tickets.sale_price")
  end

  def total_profit
    total_revenue - total_cost
  end

  def tickets_sold_count
    games.joins(:tickets).count
  end

  def total_tickets_available
    games.count * num_seats
  end

  def percentage_sold
    return 0 if total_tickets_available.zero?
    (tickets_sold_count.to_f / total_tickets_available * 100).round(2)
  end

  # Returns :on_track, :caution, or :not_on_track
  def break_even_status
    return :not_on_track if total_tickets_available.zero? || tickets_sold_count.zero?

    avg_price = total_revenue / tickets_sold_count.to_f
    projected_revenue = avg_price * total_tickets_available
    projected_profit_percent = ((projected_revenue - total_cost) / total_cost * 100)

    # Green: Projected to make 5%+ profit
    return :on_track if projected_profit_percent >= 5.0

    # Red: Projected to lose money
    return :not_on_track if projected_profit_percent < 0

    # Between 0-5% profit: Check how tight margins are
    remaining_tickets = total_tickets_available - tickets_sold_count
    return :caution if remaining_tickets <= 0 # All sold but small profit

    # Calculate what % of remaining tickets need to sell at avg price to hit 5% target
    target_revenue = total_cost * 1.05
    revenue_needed = target_revenue - total_revenue
    tickets_needed = (revenue_needed / avg_price).ceil
    percent_needed = (tickets_needed.to_f / remaining_tickets * 100).round(1)

    # Yellow/Caution: We're in 0-5% profit zone
    # Extra concern if we need to sell 75%+ of remaining tickets
    :caution
  end

  # Helper methods for view logic
  def on_track?
    break_even_status == :on_track
  end

  def caution?
    break_even_status == :caution
  end

  def not_on_track?
    break_even_status == :not_on_track
  end

  # Additional info for caution status display
  def break_even_metrics
    return {} if tickets_sold_count.zero?

    avg_price = total_revenue / tickets_sold_count.to_f
    projected_revenue = avg_price * total_tickets_available
    projected_profit = projected_revenue - total_cost
    projected_profit_percent = (projected_profit / total_cost * 100).round(1)

    remaining_tickets = total_tickets_available - tickets_sold_count
    target_revenue = total_cost * 1.05
    revenue_needed = target_revenue - total_revenue
    tickets_needed = revenue_needed > 0 ? (revenue_needed / avg_price).ceil : 0
    percent_of_remaining_needed = remaining_tickets > 0 ? (tickets_needed.to_f / remaining_tickets * 100).round(1) : 0

    {
      avg_price: avg_price,
      projected_revenue: projected_revenue,
      projected_profit: projected_profit,
      projected_profit_percent: projected_profit_percent,
      remaining_tickets: remaining_tickets,
      tickets_needed_for_target: tickets_needed,
      percent_of_remaining_needed: percent_of_remaining_needed
    }
  end

  # ============================================
  # ADVANCED FINANCIAL METRICS
  # ============================================

  # ROI: Return on Investment - industry standard metric
  # Formula: (Revenue - Cost) / Cost * 100
  def roi
    return 0.0 if total_cost.zero?
    ((total_revenue - total_cost) / total_cost * 100).round(1)
  end

  # Gross Margin: Profit as percentage of revenue
  # Formula: (Revenue - Cost) / Revenue * 100
  def gross_margin
    return 0.0 if total_revenue.zero?
    ((total_revenue - total_cost) / total_revenue * 100).round(1)
  end

  # Cost Recovery Rate: How much of investment is recouped
  # Formula: Revenue / Cost * 100
  def cost_recovery_rate
    return 0.0 if total_cost.zero?
    (total_revenue / total_cost * 100).round(1)
  end

  # Average cost per ticket across all games
  def average_cost_per_ticket
    return 0.0 if total_tickets_available.zero?
    total_cost / total_tickets_available
  end

  # Average sale price per ticket
  def average_sale_price
    return 0.0 if tickets_sold_count.zero?
    total_revenue / tickets_sold_count
  end

  # Average markup percentage across all sales
  def average_markup
    return 0.0 if tickets_sold_count.zero? || average_cost_per_ticket.zero?
    ((average_sale_price - average_cost_per_ticket) / average_cost_per_ticket * 100).round(1)
  end

  # Sell-through rate (percentage of inventory sold)
  def sell_through_rate
    percentage_sold
  end

  # Revenue per game (average)
  def average_revenue_per_game
    return 0.0 if games_with_sales_count.zero?
    total_revenue / games_with_sales_count
  end

  # Cost per game (average)
  def average_cost_per_game
    return 0.0 if games.count.zero?
    total_cost / games.count
  end

  # Games with at least one sale
  def games_with_sales_count
    games.joins(:tickets).distinct.count
  end

  # Projected ROI if remaining tickets sell at current average
  def projected_roi
    return roi if tickets_sold_count.zero?

    avg_price = average_sale_price
    remaining = total_tickets_available - tickets_sold_count
    projected_revenue = total_revenue + (avg_price * remaining)
    ((projected_revenue - total_cost) / total_cost * 100).round(1)
  end

  # Amount needed to break even
  def revenue_to_break_even
    remaining = total_cost - total_revenue
    remaining > 0 ? remaining : 0.0
  end

  # Tickets needed to break even at current average price
  def tickets_to_break_even
    return 0 if total_revenue >= total_cost
    return nil if tickets_sold_count.zero?  # Can't calculate without sales

    avg_price = average_sale_price
    remaining_cost = total_cost - total_revenue
    (remaining_cost / avg_price).ceil
  end

  # Best performing game by profit
  def best_performing_game
    games.max_by(&:profit_loss)
  end

  # Worst performing game by profit (among those with sales)
  def worst_performing_game
    games_with_sales = games.select { |g| g.tickets_sold_count > 0 }
    games_with_sales.min_by(&:profit_loss)
  end

  # ============================================
  # SEASON LIFECYCLE / STATUS
  # ============================================

  GAME_TYPES = %w[preseason regular playoff nba_cup].freeze

  # Date of the season's final game (nil if no games scheduled)
  def last_game_date
    games.maximum(:game_date)
  end

  # A season is "complete" once it has games and none remain today-or-later.
  # Auto-detected so there is no manual close-out step. This is orthogonal to
  # is_current (which marks the default season used for write operations
  # elsewhere in the app). If manually re-opening a complete season is ever
  # needed, add a closed_at:datetime column and factor it in here.
  def complete?
    games.exists? && !games.where("game_date >= ?", Date.current).exists?
  end

  # Active = not complete. A season with no games yet is active (nothing to recap).
  def active?
    !complete?
  end

  # Scheduled but not underway: games exist, none has been played, and nothing
  # has sold. ROI/margin/sell-through are all mathematically -100%/0% in this
  # state, which is technically true and useless to display — the dashboard
  # shows a commitment summary instead.
  def not_started?
    games.exists? &&
      tickets_sold_count.zero? &&
      !games.where("game_date < ?", Date.current).exists?
  end

  def first_game_date
    games.minimum(:game_date)
  end

  # Symbol for view branching
  def status
    complete? ? :complete : :active
  end

  # ============================================
  # GAME-TYPE BREAKDOWN
  # ============================================

  # Cost / revenue / profit / ROI broken out by game type. Returns an ordered
  # array (regular, playoff, nba_cup) containing only the types that have games.
  # Invariant: the sum of every row's :profit equals total_profit.
  def profit_by_game_type
    GAME_TYPES.filter_map do |type|
      type_games = games.where(game_type: type).includes(:tickets).to_a
      next if type_games.empty?

      cost         = type_games.sum(&:total_cost)
      revenue      = type_games.sum(&:total_revenue)
      tickets_sold = type_games.sum(&:tickets_sold_count)

      {
        type: type,
        label: type_label(type),
        games_count: type_games.size,
        cost: cost,
        revenue: revenue,
        profit: revenue - cost,
        roi: cost.zero? ? 0.0 : ((revenue - cost) / cost * 100).round(1),
        tickets_sold: tickets_sold
      }
    end
  end

  # ============================================
  # REVENUE OVER TIME (cumulative)
  # ============================================

  # Cumulative revenue vs cumulative cost over the season timeline, keyed by
  # month ("YYYY-MM") of each game. Computed in memory so it is database-agnostic.
  # Returns [] when there are no games.
  def monthly_financials
    season_games = games.includes(:tickets).to_a
    return [] if season_games.empty?

    by_month = season_games.group_by { |g| g.game_date.strftime("%Y-%m") }

    cumulative_revenue = 0
    cumulative_cost = 0

    by_month.keys.sort.map do |month|
      month_games = by_month[month]
      revenue = month_games.sum(&:total_revenue)
      cost = month_games.sum(&:total_cost)
      cumulative_revenue += revenue
      cumulative_cost += cost

      {
        month: month,
        revenue: revenue,
        cost: cost,
        cumulative_revenue: cumulative_revenue,
        cumulative_cost: cumulative_cost
      }
    end
  end

  # ============================================
  # RECAP / WRITE-OFF METRICS (complete seasons)
  # ============================================

  # Seats that were never sold (>= 0)
  def unsold_tickets_count
    [ total_tickets_available - tickets_sold_count, 0 ].max
  end

  # Sunk cost of unsold seats: unsold seats per game * that game's cost_per_ticket
  # (parking is a per-game cost regardless of sales and is excluded here).
  def unsold_inventory_cost
    games.includes(:tickets).sum { |g| g.tickets_available * g.cost_per_ticket }
  end

  # Semantic aliases for recap display
  alias_method :final_net_profit, :total_profit
  alias_method :final_roi, :roi

  # Comprehensive dashboard metrics hash
  def dashboard_metrics
    {
      # Core Financial
      total_cost: total_cost,
      total_revenue: total_revenue,
      total_profit: total_profit,

      # Key Performance Indicators
      roi: roi,
      gross_margin: gross_margin,
      cost_recovery_rate: cost_recovery_rate,
      sell_through_rate: sell_through_rate,
      average_markup: average_markup,

      # Ticket Metrics
      tickets_sold: tickets_sold_count,
      total_tickets: total_tickets_available,
      remaining_tickets: total_tickets_available - tickets_sold_count,
      average_cost_per_ticket: average_cost_per_ticket,
      average_sale_price: average_sale_price,

      # Game Metrics
      total_games: games.count,
      games_with_sales: games_with_sales_count,
      average_revenue_per_game: average_revenue_per_game,
      average_cost_per_game: average_cost_per_game,

      # Projections
      projected_roi: projected_roi,
      revenue_to_break_even: revenue_to_break_even,
      tickets_to_break_even: tickets_to_break_even,

      # Status
      break_even_status: break_even_status,
      profitable: total_profit >= 0
    }
  end

  private

  def type_label(type)
    {
      "preseason" => "Preseason",
      "regular" => "Regular Season",
      "playoff" => "Playoffs",
      "nba_cup" => "NBA Cup"
    }.fetch(type, type.titleize)
  end
end
