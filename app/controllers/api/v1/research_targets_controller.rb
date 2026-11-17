module Api
  module V1
    # What the research skill should scan: every upcoming game this season,
    # with what's already known about its Ticketmaster event.
    class ResearchTargetsController < BaseController
      before_action { require_scope!("market:write") }

      def index
        season = Season.find_by!(is_current: true)
        settings = Market::Settings.for(season)
        games = season.games.upcoming.includes(:opponent, :tickets, :listings, :listing_events).to_a
        latest = MarketSnapshot.latest_by_game(games.map(&:id))

        render json: {
          season: season.year,
          start_url: Market::TICKETMASTER_START_URL,
          our_seats: { section: settings.our_section, row: settings.our_row, seats: (1..season.num_seats).to_a },
          sections: [ settings.our_section, *settings.comparable_sections ],
          quantity: 2,
          games: games.map do |game|
            status = game.listing_status
            {
              id: game.id, date: game.game_date.iso8601, opponent: game.opponent.name,
              tipoff: game.tipoff_at&.iso8601, ticketmaster_event_id: game.ticketmaster_event_id,
              ticketmaster_url: game.ticketmaster_url,
              seats_to_sell: status.open_seats.size - status.held_seats.size,
              last_scanned_at: latest[game.id]&.captured_at&.iso8601
            }
          end
        }
      end
    end
  end
end
