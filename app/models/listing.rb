# Our listing of some of a game's seats on a marketplace, or a hold that keeps
# seats off the market. It records what we asked and when someone last
# confirmed it's still up; it never talks to Ticketmaster.
class Listing < ApplicationRecord
  KINDS = %w[listing hold].freeze
  STATUSES = %w[active ended].freeze
  BASES = %w[seller_list buyer_all_in].freeze
  END_REASONS = %w[sold delisted replaced].freeze
  PLATFORMS = {
    "ticketmaster" => "Ticketmaster",
    "stubhub" => "StubHub",
    "seatgeek" => "SeatGeek",
    "private" => "Private sale",
    "other" => "Other"
  }.freeze

  belongs_to :game
  belongs_to :account_user, class_name: "User", optional: true
  belongs_to :verified_by, class_name: "User", optional: true
  has_many :tickets, dependent: :nullify
  has_many :events, class_name: "ListingEvent", dependent: :restrict_with_error

  scope :active, -> { where(status: "active") }
  scope :for_sale, -> { where(kind: "listing") }
  scope :holds, -> { where(kind: "hold") }

  before_validation :normalize_seats

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :ask_price_basis, inclusion: { in: BASES }
  validates :end_reason, inclusion: { in: END_REASONS }, allow_nil: true
  validates :platform, inclusion: { in: PLATFORMS.keys }, if: :listing?
  validates :ask_price, presence: true, numericality: { greater_than: 0 }, if: :listing?
  validate :seats_available, if: -> { active? && (new_record? || will_save_change_to_seat_numbers?) }

  def listing? = kind == "listing"
  def hold? = kind == "hold"
  def active? = status == "active"
  def platform_name = PLATFORMS[platform]
  def all_in_price? = ask_price_basis == "buyer_all_in"

  # Seats this listing still covers: the ones it listed that haven't sold.
  def open_seats
    seat_numbers - game.tickets.map(&:seat_number)
  end

  def verified_fresh?(now = Time.current)
    verified_at.present? && verified_at >= now - Listings::GameStatus::VERIFICATION_MAX_AGE
  end

  private

  def normalize_seats
    self.seat_numbers = Array(seat_numbers).reject(&:blank?).map(&:to_i).uniq.sort
  end

  # Seats must exist this season, be unsold, and not already be on another
  # active listing or hold for the game.
  def seats_available
    return errors.add(:seat_numbers, "pick at least one seat") if seat_numbers.empty?

    valid = (1..game.season.num_seats)
    if (bad = seat_numbers.reject { |seat| valid.cover?(seat) }).any?
      errors.add(:seat_numbers, "#{bad.to_sentence} #{bad.one? ? "isn't a seat" : "aren't seats"} this season")
    end
    if (sold = seat_numbers & game.tickets.pluck(:seat_number)).any?
      errors.add(:seat_numbers, "seat #{sold.to_sentence} already sold")
    end
    others = game.listings.active.where.not(id: id).flat_map(&:seat_numbers)
    if (taken = seat_numbers & others).any?
      errors.add(:seat_numbers, "seat #{taken.to_sentence} is already on another listing or hold")
    end
  end
end
