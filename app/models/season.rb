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
end
