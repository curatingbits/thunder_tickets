module Attention
  # What needs doing, most urgent first. Built fresh from current data on
  # each request and never stored, so an item disappears the moment it's
  # handled. Later milestones add listing, pricing and settlement items.
  class Feed
    WINDOW_DAYS = 7

    # priority: 1 is most urgent.
    Item = Data.define(:priority, :kind, :game, :days, :seats_open)

    def initialize(season, today: Date.current)
      @season = season
      @today = today
    end

    def items
      return [] unless @season

      @items ||= unsold_soon.sort_by { |item| [ item.priority, item.game.game_date ] }
    end

    private

    # Games in the next week that still have seats to sell.
    def unsold_soon
      games = @season.games.where(game_date: @today..(@today + WINDOW_DAYS)).includes(:opponent, :tickets)
      games.filter_map do |game|
        open = game.tickets_available
        next if open.zero?

        days = game.days_until(@today)
        priority = if days <= 1 then 1
        elsif days <= 3 then 2
        else 3
        end
        Item.new(priority: priority, kind: :unsold_soon, game: game, days: days, seats_open: open)
      end
    end
  end
end
