module Settlements
  # The settlement summary as the API returns it (the skill reads this).
  module ApiJson
    module_function

    def call(summary = Summary.new)
      totals = summary.totals
      {
        partner: Settlements.partner_name, owner: Settlements.owner_name,
        window_from: summary.window_from.iso8601, last_sync_at: summary.last_sync_at&.iso8601,
        owed_cents: totals[:expected_cents], paid_cents: totals[:allocated_cents], outstanding_cents: totals[:outstanding_cents],
        games: summary.balances.map do |b|
          { game_id: b.game.id, date: b.game.game_date.iso8601, opponent: b.game.opponent.name, revenue_cents: b.revenue_cents,
            owed_cents: b.expected_cents, paid_cents: b.allocated_cents, status: b.status }
        end,
        needs_review: summary.review.map do |p|
          { id: p.id, date: p.occurred_on.iso8601, direction: p.direction, cents: p.amount_cents, memo: p.memo,
            score: p.match_confidence, reasons: p.match_details["reasons"], suggestion: p.match_details["suggestion"] }
        end
      }
    end
  end
end
