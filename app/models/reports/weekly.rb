module Reports
  # One week, Monday to Sunday (Central), rebuilt from stored history: the
  # research that ran, how the market moved, what sold, listing decisions
  # and Venmo payments. The current week adds what's coming up and what
  # needs attention. Nothing is stored. A past week comes out the same every
  # time because snapshots, listing events, sales and payments aren't
  # rewritten.
  class Weekly
    MOVE_PCT = 10
    UPCOMING_DAYS = 14
    ATTENTION_ITEMS = 5

    Move = Data.define(:game, :snapshot)
    SaleLine = Data.define(:game, :tickets, :payout)

    attr_reader :season, :week_start

    def initialize(season, week: Date.current, now: Time.current)
      @season = season
      @week_start = week.beginning_of_week(:monday)
      @now = now
    end

    def week_end = week_start + 6
    def range = week_start.in_time_zone.beginning_of_day..week_end.in_time_zone.end_of_day
    def current? = (week_start..week_end).cover?(@now.to_date)
    def future? = week_start > @now.to_date
    def previous_week = week_start - 7
    def next_week = current? ? nil : week_start + 7

    def research_runs
      @research_runs ||= ImportRun.market_research.where(started_at: range).order(:started_at).to_a
    end

    def snapshots
      @snapshots ||= MarketSnapshot.valid.joins(:game).where(games: { season_id: season.id }, captured_at: range)
                                   .includes(game: :opponent).order(:captured_at, :id).to_a
    end

    # Games whose market value moved at least MOVE_PCT since their previous scan.
    def market_moves
      snapshots.select { |s| s.market_value_change_pct && s.market_value_change_pct.abs >= MOVE_PCT }
               .sort_by { |s| -s.market_value_change_pct.abs }
               .map { |s| Move.new(game: s.game, snapshot: s) }
    end

    def median_change_pct
      Market::Stats.median(snapshots.filter_map { |s| s.market_value_change_pct&.to_f })&.round(1)
    end

    def sales
      @sales ||= Ticket.joins(:game).where(games: { season_id: season.id }).where(sold_at: range)
                       .includes(game: :opponent).to_a.group_by(&:game)
                       .map { |game, tickets| SaleLine.new(game: game, tickets: tickets, payout: tickets.sum { |t| t.sale_price.to_f }) }
                       .sort_by { |line| line.game.game_date }
    end

    def listing_events
      @listing_events ||= ListingEvent.joins(:game).where(games: { season_id: season.id }).where(occurred_at: range)
                                      .includes(:user, game: :opponent).order(:occurred_at, :id).to_a
    end

    def payments
      @payments ||= PartnerPayment.where(occurred_on: week_start..week_end).where.not(status: "ignored")
                                  .includes(allocations: { game: :opponent }).order(:occurred_on, :id).to_a
    end

    # Today's balance, not the balance at the week's end: payments and sales
    # keep arriving after a week closes.
    def settlement
      return @settlement if defined?(@settlement)

      @settlement = (Settlements::Summary.new if season.settlement_tracked && Settlements.synced?)
    end

    # Current week only: games in the next two weeks with seats to sell.
    def upcoming
      return [] unless current?

      @upcoming ||= Market::Board.new(season, now: @now).rows.select do |row|
        row.game.game_date <= @now.to_date + UPCOMING_DAYS && row.seats_to_sell.positive?
      end
    end

    def attention
      return [] unless current?

      @attention ||= Attention::Feed.new(season, today: @now.to_date, now: @now).items.first(ATTENTION_ITEMS)
    end

    def quiet? = research_runs.empty? && snapshots.empty? && sales.empty? && listing_events.empty? && payments.empty?
  end
end
