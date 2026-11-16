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
  validates :game_type, inclusion: { in: %w[preseason regular playoff nba_cup] }

  PLAYOFF_ROUNDS = [ "First Round", "Conference Semifinals", "Conference Finals", "NBA Finals" ].freeze
  NBA_CUP_ROUNDS = [ "Group Play", "Knockout Round", "Quarterfinals", "Semifinals", "Championship" ].freeze
  validate :receipt_image_size

  scope :preseason, -> { where(game_type: "preseason") }
  scope :regular_season, -> { where(game_type: "regular") }
  scope :playoffs, -> { where(game_type: "playoff") }
  scope :nba_cup, -> { where(game_type: "nba_cup") }
  scope :upcoming, -> { where("game_date >= ?", Date.current).order(:game_date) }
  scope :past, -> { where("game_date < ?", Date.current).order(game_date: :desc) }
  # Every seat sold. The seat count lives on the season, so each game is
  # compared against its own season's num_seats.
  scope :fully_sold, -> {
    where(<<~SQL.squish)
      (SELECT COUNT(*) FROM tickets WHERE tickets.game_id = games.id)
        >= (SELECT seasons.num_seats FROM seasons WHERE seasons.id = games.season_id)
    SQL
  }

  def total_cost
    (cost_per_ticket * season.num_seats) + parking_cost
  end

  def total_revenue
    tickets.sum(:sale_price)
  end

  def profit_loss
    total_revenue - total_cost
  end

  # Average each seat must sell for to cover this game's tickets and parking.
  def break_even_price_per_ticket
    total_cost / season.num_seats
  end

  # Revenue still needed to cover this game's cost; zero once it's covered.
  def remaining_to_break_even
    [ total_cost - total_revenue, 0 ].max
  end

  # What each unsold seat must go for to break even, or nil when nothing is
  # left to sell or the game has already covered its cost.
  def break_even_price_for_remaining
    return nil if tickets_available.zero? || remaining_to_break_even.zero?

    remaining_to_break_even / tickets_available
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

  def preseason?
    game_type == "preseason"
  end

  def playoff?
    game_type == "playoff"
  end

  def nba_cup?
    game_type == "nba_cup"
  end

  # NBA Cup group-play games are part of the regular-season package, so they
  # stay game_type "regular" for cost purposes and carry the round instead.
  # Either shape should read as "NBA Cup" in the UI.
  def cup_round
    return playoff_round if nba_cup? || (regular? && playoff_round.present?)

    nil
  end

  private

  def receipt_image_size
    if receipt_image.attached? && receipt_image.blob.byte_size > 15.megabytes
      errors.add(:receipt_image, "must be less than 15MB")
    end
  end
end
