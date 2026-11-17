module Listings
  # A game's listing status, derived from its seats, sales, listings and
  # listing events. Never stored, so it can't drift from the facts.
  #
  # "Not listed" needs a positive confirmation (a verified_unlisted event).
  # With no information, or a listing nobody has confirmed lately, the answer
  # is "Needs verification", never a guess.
  class GameStatus
    VERIFICATION_MAX_AGE = 7.days

    LABELS = {
      transferred: "Transferred",
      sold: "Sold",
      unsold: "Unsold",
      reserved: "Reserved",
      listed: "Listed",
      partially_sold: "Partially sold",
      not_listed: "Not listed",
      needs_verification: "Needs verification"
    }.freeze

    Result = Data.define(:status, :open_seats, :listed_seats, :held_seats, :listings, :sold_count,
                         :untransferred_count, :verified_at, :confirmed_unlisted_at) do
      def label = LABELS.fetch(status)
      def ask_prices = listings.select(&:listing?).filter_map(&:ask_price).uniq.sort
      def unlisted_seats = open_seats - listed_seats - held_seats
    end

    def self.for(game, now: Time.current)
      new(game, now: now).result
    end

    def initialize(game, now: Time.current)
      @game = game
      @now = now
    end

    def result
      tickets = @game.tickets.to_a
      sold = tickets.map(&:seat_number)
      open = (1..@game.season.num_seats).to_a - sold
      active = @game.listings.select(&:active?)
      for_sale = active.select(&:listing?)
      held = active.select(&:hold?).flat_map(&:seat_numbers) & open
      covering = for_sale.select { |listing| (listing.seat_numbers & open).any? }
      listed = covering.flat_map(&:seat_numbers) & open
      to_sell = open - held
      confirmed_unlisted_at = latest_unlisted_confirmation

      status =
        if open.empty?
          tickets.all?(&:transferred_at) ? :transferred : :sold
        elsif @game.game_date < @now.to_date
          :unsold
        elsif to_sell.empty?
          :reserved
        elsif (to_sell - listed).empty? && covering.all? { |listing| listing.verified_fresh?(@now) }
          sold.any? ? :partially_sold : :listed
        elsif listed.empty? && confirmed_unlisted_at
          sold.any? ? :partially_sold : :not_listed
        else
          :needs_verification
        end

      Result.new(status: status, open_seats: open, listed_seats: listed, held_seats: held, listings: covering,
                 sold_count: sold.size, untransferred_count: tickets.count { |t| t.transferred_at.nil? },
                 verified_at: covering.filter_map(&:verified_at).min, confirmed_unlisted_at: confirmed_unlisted_at)
    end

    private

    # A recent "confirmed not listed" that nothing has superseded since (a
    # newer listing would mean the seats went back up).
    def latest_unlisted_confirmation
      events = @game.listing_events.to_a
      latest = events.select { |e| e.action == "verified_unlisted" }.max_by(&:occurred_at)
      return unless latest && latest.occurred_at >= @now - VERIFICATION_MAX_AGE

      relisted = events.any? { |e| e.action.in?(%w[listed held]) && e.occurred_at > latest.occurred_at }
      latest.occurred_at unless relisted
    end
  end
end
