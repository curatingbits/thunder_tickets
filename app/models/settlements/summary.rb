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

    # The latest payments, newest first, leaving out the ones set aside as
    # unrelated. Money lists eight; Home's Payouts shows three.
    def recent(limit)
      PartnerPayment.recent_first.where.not(status: "ignored").includes(allocations: { game: :opponent }).limit(limit)
    end

    # The finance feed serves at most 400 days per request.
    MAX_WINDOW_DAYS = 395

    # Fetch window for the sync: back to whichever starts first, game
    # payments (Settlements.tracking_starts_on) or season-ticket installments
    # (Settlements.cost_share_starts_on), but no more than MAX_WINDOW_DAYS.
    def window_from
      starts = [ Settlements.tracking_starts_on, Settlements.cost_share_starts_on ].compact.min || Date.current - 90
      [ starts, Date.current - MAX_WINDOW_DAYS ].max
    end
  end
end
