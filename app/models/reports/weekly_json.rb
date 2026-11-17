module Reports
  # The weekly report as the API returns it, for skills that write it up.
  module WeeklyJson
    module_function

    def call(report, helpers: ApplicationController.helpers)
      {
        week_start: report.week_start.iso8601, week_end: report.week_end.iso8601, current: report.current?,
        research: report.research_runs.map do |run|
          { id: run.id, status: run.status, started_at: run.started_at.iso8601, games_scanned: run.market_snapshots.size }
        end,
        market: {
          games_scanned: report.snapshots.size, median_change_pct: report.median_change_pct,
          moves: report.market_moves.map do |m|
            game_json(m.game).merge(change_pct: m.snapshot.market_value_change_pct.to_f, market_value: m.snapshot.market_value&.to_f)
          end
        },
        sales: report.sales.map { |line| game_json(line.game).merge(tickets: line.tickets.size, payout: line.payout.round(2)) },
        listing_events: report.listing_events.map do |e|
          game_json(e.game).merge(action: e.action, occurred_at: e.occurred_at.iso8601,
                                  price_before: e.price_before&.to_f, price_after: e.price_after&.to_f)
        end,
        payments: report.payments.map do |p|
          { id: p.id, date: p.occurred_on.iso8601, direction: p.direction, cents: p.amount_cents, memo: p.memo, status: p.status }
        end,
        balance: report.settlement&.totals&.slice(:expected_cents, :allocated_cents, :outstanding_cents),
        upcoming: report.upcoming.map do |row|
          game_json(row.game).merge(seats_to_sell: row.seats_to_sell, listing_status: row.status.status,
                                    assessment: row.assessment, recommended_list_price: row.snapshot&.recommended_list_price&.to_f)
        end,
        attention: report.attention.map do |item|
          { kind: item.kind, priority: item.priority, game_id: item.game&.id, title: helpers.attention_title(item) }
        end
      }
    end

    def game_json(game) = { game_id: game.id, date: game.game_date.iso8601, opponent: game.opponent.name }
  end
end
