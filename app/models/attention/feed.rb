module Attention
  # What needs doing, most urgent first. Built fresh from current data on
  # each request and never stored, so an item disappears the moment it's
  # handled. Settlement items join in a later milestone.
  class Feed
    WINDOW_DAYS = 7            # open seats this close are urgent
    REPRICE_WINDOW_DAYS = 14   # over/underpriced listings worth acting on
    LISTING_WINDOW_DAYS = 21   # how far ahead listings should be confirmed
    TRANSFER_WINDOW_DAYS = 3   # sold tickets should be with the buyer by now
    STALE_RESEARCH = 8.days
    MARKET_DROP_PCT = -10

    KIND_ORDER = %i[research_blocked transfer_pending unsold_soon reprice settlement_review not_listed verify_listing
                    market_drop research_stale payout_overdue].freeze
    PAYOUT_OVERDUE = 14.days

    # priority: 1 is most urgent. seats_open excludes held seats. game is nil
    # for season-wide items (research runs).
    Item = Data.define(:priority, :kind, :game, :days, :seats_open, :status, :snapshot, :assessment)

    def initialize(season, today: Date.current, now: nil)
      @season = season
      @today = today
      @now = now || (today == Date.current ? Time.current : today.in_time_zone.change(hour: 12))
    end

    def items
      return [] unless @season

      @items ||= (game_items + research_items + settlement_items).sort_by do |item|
        [ item.priority, item.game&.game_date || @today, KIND_ORDER.index(item.kind) ]
      end
    end

    private

    def game_items
      games = @season.games.where(game_date: @today..(@today + LISTING_WINDOW_DAYS))
                     .includes(:opponent, :tickets, :listings, :listing_events).to_a
      @snapshots = MarketSnapshot.latest_by_game(games.map(&:id))
      @settings = Market::Settings.for(@season)
      games.flat_map { |game| items_for(game) }
    end

    def items_for(game)
      days = game.days_until(@today)
      status = game.listing_status(now: @now)
      snapshot = @snapshots[game.id]
      to_sell = status.open_seats.size - status.held_seats.size
      item = lambda do |priority, kind, assessment = nil|
        Item.new(priority: priority, kind: kind, game: game, days: days, seats_open: to_sell, status: status,
                 snapshot: snapshot, assessment: assessment)
      end

      found = []
      found << item.(1, :transfer_pending) if days <= TRANSFER_WINDOW_DAYS && status.untransferred_count.positive?
      return found unless to_sell.positive?

      if days <= WINDOW_DAYS
        found << item.(urgency(days), :unsold_soon)
      elsif status.status == :not_listed
        found << item.(3, :not_listed)
      elsif status.status == :needs_verification
        found << item.(3, :verify_listing)
      end

      if snapshot&.market_value && days <= REPRICE_WINDOW_DAYS
        ours = Market::Assessment.our_all_in(status, snapshot.buyer_fee_multiplier.to_f)
        assessment = Market::Assessment.call(listing_status: status, our_all_in: ours, market_value: snapshot.market_value.to_f,
                                             confidence: snapshot.confidence_now(@now), settings: @settings)
        found << item.(2, :reprice, assessment) if assessment.in?(%w[overpriced underpriced])
      end
      if snapshot&.market_value_change_pct && snapshot.market_value_change_pct <= MARKET_DROP_PCT
        found << item.(3, :market_drop)
      end
      found
    end

    # Season-wide: a blocked research run, or market data going stale.
    def research_items
      found = []
      run = ImportRun.market_research.where.not(source: "manual").recent_first.first
      if run&.status.in?(%w[blocked failed]) && run.started_at > @now - STALE_RESEARCH
        found << global_item(1, :research_blocked)
      end
      latest = MarketSnapshot.valid.joins(:game).where(games: { season_id: @season.id }).maximum(:captured_at)
      found << global_item(3, :research_stale) if latest && latest < @now - STALE_RESEARCH
      found
    end

    # Payments waiting for a person, and payouts still owed two weeks after
    # the last sale.
    def settlement_items
      return [] unless @season.settlement_tracked

      found = []
      review = PartnerPayment.where(status: "needs_review").count
      found << global_item(2, :settlement_review, review) if review.positive?
      return found unless Settlements.synced?

      overdue = Settlements::Ledger.new([ @season ]).balances.select do |b|
        b.outstanding_cents > b.tolerance && b.game.tickets.map(&:sold_at).compact.max.to_i < (@now - PAYOUT_OVERDUE).to_i
      end
      found << global_item(4, :payout_overdue, overdue) if overdue.any?
      found
    end

    def global_item(priority, kind, detail = nil)
      Item.new(priority: priority, kind: kind, game: nil, days: nil, seats_open: 0, status: nil, snapshot: nil, assessment: detail)
    end

    def urgency(days)
      if days <= 1 then 1
      elsif days <= 3 then 2
      else 3
      end
    end
  end
end
