class Game < ApplicationRecord
  belongs_to :season
  belongs_to :opponent, class_name: "Team"
  has_many :tickets, dependent: :destroy

  validates :game_number, presence: true, uniqueness: { scope: :season_id }
  validates :game_date, presence: true
  validates :cost_per_ticket, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :parking_cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :game_type, inclusion: { in: %w[regular playoff] }

  scope :regular_season, -> { where(game_type: "regular") }
  scope :playoffs, -> { where(game_type: "playoff") }
  scope :upcoming, -> { where("game_date >= ?", Date.current).order(:game_date) }
  scope :past, -> { where("game_date < ?", Date.current).order(game_date: :desc) }

  def total_cost
    (cost_per_ticket * season.num_seats) + parking_cost
  end

  def total_revenue
    tickets.sum(:sale_price)
  end

  def profit_loss
    total_revenue - total_cost
  end

  def tickets_sold_count
    tickets.count
  end

  def tickets_available
    season.num_seats - tickets_sold_count
  end

  def fully_sold?
    tickets_available.zero?
  end

  def partially_sold?
    tickets_sold_count > 0 && tickets_sold_count < season.num_seats
  end

  def unsold?
    tickets_sold_count.zero?
  end
end
