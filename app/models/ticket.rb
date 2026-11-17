class Ticket < ApplicationRecord
  belongs_to :game
  belongs_to :buyer, optional: true
  belongs_to :listing, optional: true

  validates :seat_number, presence: true, uniqueness: { scope: :game_id }
  validates :sale_price, presence: true, numericality: { greater_than: 0 }

  before_create :set_sold_at
  before_create :link_listing
  before_create :mark_marketplace_transfer
  after_create :close_sold_out_listing

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

  def transferred?
    transferred_at.present?
  end

  private

  def set_sold_at
    self.sold_at ||= Time.current
  end

  # A sale of a listed seat came from that listing: link it and keep the
  # asking price, so seller fees can be measured from real payouts.
  def link_listing
    self.listing ||= game.listings.active.for_sale.find { |candidate| candidate.seat_numbers.include?(seat_number) }
    self.list_price_at_sale ||= listing.ask_price if listing && !listing.all_in_price?
  end

  # Ticketmaster resale delivers the tickets itself when they sell.
  def mark_marketplace_transfer
    marketplace = listing&.platform == "ticketmaster" || buyer&.name&.casecmp?("Ticketmaster")
    self.transferred_at ||= sold_at if marketplace
  end

  # Once every seat on a listing has sold, the listing is done.
  def close_sold_out_listing
    return unless listing&.active?
    return unless (listing.seat_numbers - game.tickets.pluck(:seat_number)).empty?

    listing.update!(status: "ended", end_reason: "sold", ended_at: Time.current)
    ListingEvent.create!(game: game, listing: listing, action: "ended", price_before: listing.ask_price,
                         note: "All seats sold")
  end
end
