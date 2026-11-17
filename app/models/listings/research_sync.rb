module Listings
  # Keeps our Ticketmaster listing in step with what the research saw, as
  # Duggan asked on 2026-11-16: a listing in our row (Section 101, Row DD)
  # means our open seats are listed at that price, and nothing in our row
  # after a complete read means they aren't. It runs inside the scan's
  # transaction, before pricing, so our own listing is never priced against
  # itself. Holds and other platforms are left alone, and every change is a
  # ListingEvent tied to the scan.
  #
  # Limits: the research reads listings for a pair, so a listing that only
  # sells all three seats together doesn't show; and another Row DD seat
  # holder's listing would look like ours. Two different prices in our row
  # are left for a person to sort out.
  class ResearchSync
    Result = Data.define(:outcome, :price, :seats, :prices)

    SEEN = "Seen on Ticketmaster by the research (all-in price)"
    GONE = "Not seen on Ticketmaster by the research"

    attr_reader :result

    def initialize(game:, listings:, settings:, scroll_complete:, now:)
      @game = game
      @scroll_complete = scroll_complete
      @now = now
      resale = listings.reject { |l| l[:ticket_type] == "standard_admission" }
      @ours = resale.select { |l| l[:section] == settings.our_section && l[:row] == settings.our_row }
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
      if listing.nil?
        listing = @game.listings.create!(kind: "listing", seat_numbers: seats, platform: "ticketmaster", ask_price: price,
                                         ask_price_basis: "buyer_all_in", verified_at: @now, notes: SEEN)
        @events << { listing: listing, action: "listed", price_after: price, note: SEEN }
        outcome(:listed, price: price, seats: seats)
      elsif (all_in(listing) - price).abs <= 1
        listing.update!(verified_at: @now, verified_by: nil)
        @events << { listing: listing, action: "verified", price_after: all_in(listing).round(2), note: SEEN }
        outcome(:confirmed, price: price, seats: listing.open_seats)
      else
        before = all_in(listing).round(2)
        listing.update!(ask_price: price, ask_price_basis: "buyer_all_in", verified_at: @now, verified_by: nil)
        @events << { listing: listing, action: "price_changed", price_before: before, price_after: price, note: SEEN }
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

    def all_in(listing)
      listing.all_in_price? ? listing.ask_price : listing.ask_price * @multiplier
    end

    def outcome(name, price: nil, seats: [], prices: [])
      Result.new(outcome: name.to_s, price: price&.to_f, seats: seats, prices: prices.map(&:to_f))
    end
  end
end
