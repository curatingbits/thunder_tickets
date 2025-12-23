class Game < ApplicationRecord
  belongs_to :season
  belongs_to :opponent, class_name: "Team"
  has_many :tickets, dependent: :destroy
  has_one :market_price, dependent: :destroy
  has_one_attached :receipt_image

  validates :game_number, presence: true, uniqueness: { scope: :season_id }
  validates :game_date, presence: true
  validates :cost_per_ticket, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :parking_cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :game_type, inclusion: { in: %w[regular playoff nba_cup] }

  PLAYOFF_ROUNDS = ["First Round", "Conference Semifinals", "Conference Finals", "NBA Finals"].freeze
  NBA_CUP_ROUNDS = ["Group Play", "Knockout Round", "Quarterfinals", "Semifinals", "Championship"].freeze
  validate :receipt_image_size

  scope :regular_season, -> { where(game_type: "regular") }
  scope :playoffs, -> { where(game_type: "playoff") }
  scope :nba_cup, -> { where(game_type: "nba_cup") }
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

  def regular?
    game_type == "regular"
  end

  def playoff?
    game_type == "playoff"
  end

  def nba_cup?
    game_type == "nba_cup"
  end

  private

  def receipt_image_size
    if receipt_image.attached? && receipt_image.blob.byte_size > 15.megabytes
      errors.add(:receipt_image, "must be less than 15MB")
    end
  end
end
