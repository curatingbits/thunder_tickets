class Ticket < ApplicationRecord
  belongs_to :game

  validates :seat_number, presence: true, uniqueness: { scope: :game_id }
  validates :sale_price, presence: true, numericality: { greater_than: 0 }

  before_create :set_sold_at

  private

  def set_sold_at
    self.sold_at ||= Time.current
  end
end
