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

  def on_track_to_break_even?
    return false if total_tickets_available.zero?

    avg_price_per_ticket = total_revenue / tickets_sold_count.to_f if tickets_sold_count > 0
    return false unless avg_price_per_ticket

    projected_revenue = avg_price_per_ticket * total_tickets_available
    projected_revenue >= total_cost
  end
end
