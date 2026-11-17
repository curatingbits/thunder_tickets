# A Venmo payment between Duggan and Mark: imported read-only from the finance
# app, or entered by hand. Amount in cents, always positive; direction says
# who paid whom. Never deleted.
class PartnerPayment < ApplicationRecord
  SOURCES = %w[finance_api manual].freeze
  DIRECTIONS = %w[incoming outgoing].freeze
  CATEGORIES = %w[settlement cost_share unrelated unknown].freeze
  STATUSES = %w[unmatched partially_matched matched needs_review ignored].freeze
  OPEN = %w[unmatched partially_matched needs_review].freeze

  belongs_to :import_run, optional: true
  belongs_to :possible_duplicate_of, class_name: "PartnerPayment", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :allocations, class_name: "SettlementAllocation", dependent: :restrict_with_error
  has_many :audit_events, as: :auditable, dependent: :restrict_with_error

  validates :source, inclusion: { in: SOURCES }
  validates :external_id, presence: true, uniqueness: { scope: :source }
  validates :occurred_on, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :category, inclusion: { in: CATEGORIES }
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(occurred_on: :desc, id: :desc) }
  scope :open, -> { where(status: OPEN) }
  scope :incoming, -> { where(direction: "incoming") }

  def incoming? = direction == "incoming"
  def amount = amount_cents / 100.0

  # Cents from Duggan's side: + when Mark paid him, - when he paid Mark.
  # Toward Duggan's season-ticket share: what he paid Mark, less refunds.
  def signed_for_cost_share = incoming? ? -amount_cents : amount_cents

  def signed_cents
    incoming? ? amount_cents : -amount_cents
  end

  def active_allocations
    allocations.select { |a| a.voided_at.nil? }
  end

  def allocated_cents
    active_allocations.sum { |a| a.amount_cents.abs }
  end

  def unallocated_cents
    amount_cents - allocated_cents
  end

  # Matched / partially matched from what's allocated; review and ignore are
  # decisions and stay put.
  def refresh_status!
    return if status.in?(%w[ignored needs_review]) && allocated_cents.zero?

    new_status = if allocated_cents.zero? then "unmatched"
    elsif allocated_cents >= amount_cents then "matched"
    else "partially_matched"
    end
    update!(status: new_status) if status != new_status
  end
end
