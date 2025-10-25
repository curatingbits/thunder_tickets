class MarketPrice < ApplicationRecord
  belongs_to :game

  validates :section, presence: true
  validates :fetched_at, presence: true

  scope :recent, -> { where("fetched_at > ?", 24.hours.ago) }
  scope :for_section, ->(section) { where(section: section) }

  def fresh?
    fetched_at && fetched_at > 24.hours.ago
  end

  def price_range
    return nil unless min_price && max_price
    "$#{min_price.to_i}-$#{max_price.to_i}"
  end

  def vs_game_cost(game_cost)
    return nil unless average_price
    diff = average_price - game_cost
    percentage = ((diff / game_cost) * 100).round(1)
    {
      difference: diff,
      percentage: percentage,
      higher: diff > 0
    }
  end
end
