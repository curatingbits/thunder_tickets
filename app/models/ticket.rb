class Ticket < ApplicationRecord
  belongs_to :game
  belongs_to :buyer, optional: true

  validates :seat_number, presence: true, uniqueness: { scope: :game_id }
  validates :sale_price, presence: true, numericality: { greater_than: 0 }

  before_create :set_sold_at

  # The edit form works in dates, but sold_at keeps a time of day so sales
  # recorded on the same day stay in order. Moving a sale to a new date keeps
  # its original time; submitting the date it already has changes nothing.
  def sold_on
    sold_at&.to_date
  end

  def sold_on=(value)
    date = ActiveModel::Type::Date.new.cast(value)
    return if date.nil? || date == sold_on

    self.sold_at = (sold_at || Time.current).change(year: date.year, month: date.month, day: date.day)
  end

  private

  def set_sold_at
    self.sold_at ||= Time.current
  end
end
