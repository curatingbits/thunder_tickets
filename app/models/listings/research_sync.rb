module Listings
  # Keeps our Ticketmaster listing in step with what the research saw, as
  # Duggan asked on 2026-11-16. Our seats are Section 101, Row DD, Seats 1-3,
  # and only those count: the reader opens each listing in our row to read
  # its seat numbers.
  # - A listing with any of our seats: the open seats are listed at its price.
  # - No listing with our seats, after a complete read: not listed. That
  #   includes other people's Row DD listings, such as seats 6-7.
  # - A Row DD listing whose seats couldn't be read: no change ("unconfirmed").
  # - Our seats at two different prices: no change ("unclear").
  # It runs inside the scan's transaction, before pricing, so our own listing
  # is never priced against itself. Holds and other platforms are left alone,
  # and every change is a ListingEvent tied to the scan.
  #
  # Limit: the research reads listings for a pair, so a listing that only
  # sells all three seats together doesn't show.
  class ResearchSync
    Result = Data.define(:outcome, :price, :seats, :prices, :seen_seats)

    GONE = "Not seen on Ticketmaster by the research"

    attr_reader :result

    def initialize(game:, listings:, settings:, scroll_complete:, now:)
      @game = game
      @scroll_complete = scroll_complete
      @now = now
      resale = listings.reject { |l| l[:ticket_type] == "standard_admission" }
      @our_row = resale.select { |l| l[:section] == settings.our_section && l[:row] == settings.our_row }
      our_seats = (1..game.season.num_seats).to_a
      @ours = @our_row.select { |l| l[:seats]&.intersect?(our_seats) }
      @unread = @our_row.select { |l| l[:seats].nil? }
      @multiplier = Market::FeeModel.detect(resale.map { |l| l[:price] }, settings.buyer_fee_multiplier).multiplier
      @events = []
    end

    def apply
      prices = @ours.map { |l| BigDecimal(l[:price].to_s).round(2) }.uniq.sort
      active = @game.listings.select(&:active?)
      ticketmaster = active.select { |l| l.listing? && l.platform == "ticketmaster" }
      elsewhere = active.select { |l| l.listing? && l.platform != "ticketmaster" }
      seats = open_seats(active, elsewhere)

      @result =
        if prices.size > 1 then outcome(:unclear, prices: prices)
        elsif seats.empty? then outcome(:nothing_to_sell, prices: prices)
        elsif prices.one? then seen(prices.first, ticketmaster.first, seats)
        elsif @unread.any? then outcome(:unconfirmed, prices: @unread.map { |l| l[:price] })
        elsif !@scroll_complete then outcome(:incomplete)
        else not_seen(ticketmaster, elsewhere, seats)
        end
    end

    # After the snapshot exists, so each event can point at it.
    def record_events!(snapshot)
      @events.each do |attrs|
        advice = attrs[:action].in?(%w[listed price_changed]) ?
          { recommended_strategy: snapshot.recommended_strategy, recommended_list_price: snapshot.recommended_list_price } : {}
        ListingEvent.create!(game: @game, occurred_at: @now, market_snapshot: snapshot, **advice, **attrs)
      end
    end

    private

    # Unsold seats that aren't held or on another platform's listing.
    def open_seats(active, elsewhere)
      sold = @game.tickets.map(&:seat_number)
      held = active.select(&:hold?).flat_map(&:seat_numbers)
      (1..@game.season.num_seats).to_a - sold - held - elsewhere.flat_map(&:seat_numbers)
    end

    def seen(price, listing, seats)
      note = "Seen on Ticketmaster by the research: Section #{@our_row.first[:section]}, Row #{@our_row.first[:row]}, " \
             "#{seat_text(seen_seats)} at #{ActiveSupport::NumberHelper.number_to_currency(price)} all-in"
      if listing.nil?
        listing = @game.listings.create!(kind: "listing", seat_numbers: seats, platform: "ticketmaster", ask_price: price,
                                         ask_price_basis: "buyer_all_in", verified_at: @now, notes: note)
        @events << { listing: listing, action: "listed", price_after: price, note: note }
        outcome(:listed, price: price, seats: seats)
      elsif (all_in(listing) - price).abs <= 1
        listing.update!(verified_at: @now, verified_by: nil)
        @events << { listing: listing, action: "verified", price_after: all_in(listing).round(2), note: note }
        outcome(:confirmed, price: price, seats: listing.open_seats)
      else
        before = all_in(listing).round(2)
        listing.update!(ask_price: price, ask_price_basis: "buyer_all_in", verified_at: @now, verified_by: nil)
        @events << { listing: listing, action: "price_changed", price_before: before, price_after: price, note: note }
        outcome(:repriced, price: price, seats: listing.open_seats)
      end
    end

    def not_seen(ticketmaster, elsewhere, seats)
      ticketmaster.each do |listing|
        before = all_in(listing).round(2)
        listing.update!(status: "ended", end_reason: "delisted", ended_at: @now)
        @events << { listing: listing, action: "ended", price_before: before, note: GONE }
      end
      @events << { listing: nil, action: "verified_unlisted", note: GONE } if elsewhere.empty?
      outcome(:not_listed, seats: seats)
    end

    def seen_seats = @ours.flat_map { |l| l[:seats] }.uniq.sort

    def seat_text(seats)
      seats.size == 1 ? "Seat #{seats.first}" : "Seats #{seats.first}-#{seats.last}"
    end

    def all_in(listing)
      listing.all_in_price? ? listing.ask_price : listing.ask_price * @multiplier
    end

    def outcome(name, price: nil, seats: [], prices: [])
      Result.new(outcome: name.to_s, price: price&.to_f, seats: seats, prices: prices.map(&:to_f),
                 seen_seats: (seen_seats if name.in?(%i[listed confirmed repriced])) || [])
    end
  end
end
