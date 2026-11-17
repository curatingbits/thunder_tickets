module Settlements
  # The settlement picture in one place: totals, each sold game's balance,
  # the review queue, and when payments were last synced.
  class Summary
    attr_reader :ledger

    def initialize(ledger = Ledger.new)
      @ledger = ledger
    end

    def totals = ledger.totals
    def balances = ledger.balances
    def review = PartnerPayment.where(status: "needs_review").recent_first
    def last_sync_at = ImportRun.where(kind: "payment_sync", status: "completed").maximum(:finished_at)
    def synced? = Settlements.synced?

    # The finance feed serves at most 400 days per request.
    MAX_WINDOW_DAYS = 395

    # Fetch window for the skill: from 90 days before the first tracked game
    # (payments often come before the game), but no more than MAX_WINDOW_DAYS back.
    def window_from
      first = Game.joins(:season).where(seasons: { settlement_tracked: true }).minimum(:game_date)
      [ (first || Date.current) - 90, Date.current - MAX_WINDOW_DAYS ].max
    end
  end
end
