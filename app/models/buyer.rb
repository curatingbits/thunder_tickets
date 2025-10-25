class Buyer < ApplicationRecord
  has_many :tickets, dependent: :nullify

  validates :name, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_name, -> { order(:name) }

  def total_spent
    tickets.sum(:sale_price)
  end

  def tickets_count
    tickets.count
  end
end
