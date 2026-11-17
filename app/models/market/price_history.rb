module Market
  # One game's market over time, oldest scan first, for the chart and table
  # on the game page. All-in per ticket; "ours" is our ask when the scan ran.
  class PriceHistory
    Point = Data.define(:captured_at, :days_to_game, :market_value, :competitive, :premium, :recommended_list, :our_all_in)

    def initialize(game)
      @game = game
    end

    def points
      @points ||= @game.market_snapshots.valid.where.not(market_value: nil).order(:captured_at, :id).map do |s|
        Point.new(captured_at: s.captured_at, days_to_game: s.days_to_game, market_value: s.market_value.to_f,
                  competitive: s.competitive_price&.to_f, premium: s.premium_price&.to_f,
                  recommended_list: s.recommended_list_price&.to_f, our_all_in: s.our_all_in&.to_f)
      end
    end

    def chartable? = points.size >= 2

    def chart_data
      points.map do |p|
        { label: p.captured_at.strftime("%b %-d"), days: p.days_to_game, market: p.market_value.round,
          low: p.competitive&.round, high: p.premium&.round, list: p.recommended_list&.round, ours: p.our_all_in&.round }
      end
    end
  end
end
