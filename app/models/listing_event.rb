# One listing decision: listed, repriced, verified, confirmed not listed,
# held, ended. Append-only, so the history of what we asked (and what the app
# recommended at the time) stays trustworthy.
class ListingEvent < ApplicationRecord
  ACTIONS = %w[listed price_changed verified verified_unlisted held ended].freeze

  belongs_to :game
  belongs_to :listing, optional: true
  belongs_to :user, optional: true

  before_validation { self.occurred_at ||= Time.current }

  validates :action, inclusion: { in: ACTIONS }
  validates :occurred_at, presence: true

  scope :recent_first, -> { order(occurred_at: :desc, id: :desc) }

  def readonly?
    persisted?
  end
end
