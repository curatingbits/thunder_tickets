module Market
  # The pricing board: every upcoming game with its live listing status,
  # latest market snapshot and an assessment of our price against it. Built
  # fresh on each request; nothing here is stored.
  class Board
    Row = Data.define(:game, :status, :snapshot, :assessment, :our_all_in, :confidence, :freshness) do
      def seats_to_sell = status.open_seats.size - status.held_seats.size
      def unsold? = status.open_seats.any?
      def needs_action? = assessment.in?(%w[overpriced underpriced not_listed needs_verification])
    end

    attr_reader :season, :settings

    def initialize(season, now: Time.current)
      @season = season
      @now = now
      @settings = Settings.for(season)
    end

    def rows
      @rows ||= begin
        games = @season.games.upcoming.includes(:opponent, :tickets, :listings, :listing_events).to_a
        latest = MarketSnapshot.latest_by_game(games.map(&:id))
        games.map { |game| row_for(game, latest[game.id]) }
      end
    end

    # What Pricing lists: games with seats still to sell, or market data to
    # read. Home's next three unsold games are the first of these.
    def shown_rows
      rows.select { |row| row.seats_to_sell.positive? || row.snapshot }
    end

    def last_run
      @last_run ||= ImportRun.market_research.recent_first.first
    end

    private

    def row_for(game, snapshot)
      status = game.listing_status(now: @now)
      multiplier = snapshot&.buyer_fee_multiplier&.to_f || @settings.buyer_fee_multiplier
      ours = Assessment.our_all_in(status, multiplier)
      confidence = snapshot ? snapshot.confidence_now(@now) : 0
      assessment =
        if snapshot
          Assessment.call(listing_status: status, our_all_in: ours, market_value: snapshot.market_value&.to_f,
                          confidence: confidence, settings: @settings)
        elsif status.open_seats.any? && status.status.in?(%i[not_listed needs_verification])
          status.status.to_s
        elsif status.open_seats.any? && status.status != :reserved
          "no_data"
        end
      Row.new(game: game, status: status, snapshot: snapshot, assessment: assessment, our_all_in: ours,
              confidence: confidence, freshness: snapshot&.freshness(@now))
    end
  end
end
