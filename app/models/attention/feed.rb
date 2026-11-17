module Attention
  # What needs doing, most urgent first. Built fresh from current data on
  # each request and never stored, so an item disappears the moment it's
  # handled. Later milestones add pricing and settlement items.
  class Feed
    WINDOW_DAYS = 7            # open seats this close are urgent
    LISTING_WINDOW_DAYS = 21   # how far ahead listings should be confirmed
    TRANSFER_WINDOW_DAYS = 3   # sold tickets should be with the buyer by now

    KIND_ORDER = %i[transfer_pending unsold_soon not_listed verify_listing].freeze

    # priority: 1 is most urgent. seats_open excludes held seats.
    Item = Data.define(:priority, :kind, :game, :days, :seats_open, :status)

    def initialize(season, today: Date.current, now: nil)
      @season = season
      @today = today
      @now = now || (today == Date.current ? Time.current : today.in_time_zone.change(hour: 12))
    end

    def items
      return [] unless @season

      @items ||= build.sort_by { |item| [ item.priority, item.game.game_date, KIND_ORDER.index(item.kind) ] }
    end

    private

    def build
      games = @season.games.where(game_date: @today..(@today + LISTING_WINDOW_DAYS))
                     .includes(:opponent, :tickets, :listings, :listing_events)
      games.flat_map { |game| items_for(game) }
    end

    def items_for(game)
      days = game.days_until(@today)
      status = game.listing_status(now: @now)
      to_sell = status.open_seats.size - status.held_seats.size
      item = ->(priority, kind) { Item.new(priority: priority, kind: kind, game: game, days: days, seats_open: to_sell, status: status) }

      found = []
      found << item.(1, :transfer_pending) if days <= TRANSFER_WINDOW_DAYS && status.untransferred_count.positive?
      if to_sell.positive?
        if days <= WINDOW_DAYS
          found << item.(urgency(days), :unsold_soon)
        elsif status.status == :not_listed
          found << item.(3, :not_listed)
        elsif status.status == :needs_verification
          found << item.(3, :verify_listing)
        end
      end
      found
    end

    def urgency(days)
      if days <= 1 then 1
      elsif days <= 3 then 2
      else 3
      end
    end
  end
end
