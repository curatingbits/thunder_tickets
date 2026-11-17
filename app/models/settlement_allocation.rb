# Part (or all) of a payment applied to one game. Signed cents from Duggan's
# side (positive: Mark paid Duggan). Voided, never deleted.
class SettlementAllocation < ApplicationRecord
  belongs_to :partner_payment
  belongs_to :game
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :voided_by, class_name: "User", optional: true
  belongs_to :replaces, class_name: "SettlementAllocation", optional: true

  validates :amount_cents, numericality: { only_integer: true, other_than: 0 }
  validates :method, inclusion: { in: %w[auto manual] }
  validates :reason, presence: true

  scope :active, -> { where(voided_at: nil) }

  def active? = voided_at.nil?
end
