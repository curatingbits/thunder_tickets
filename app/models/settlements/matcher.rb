module Settlements
  # Pairs Mark's incoming Venmo payments with the sold games they settle.
  #
  # Each game the memo mentions is scored: opponent +35, the memo's date
  # within a day +30 (within 3 days +15), a preseason/playoff hint that singles
  # out one game +20, the only game with that opponent still owed +10, the
  # buyer's name +5. The amount then has to fit: exactly what those games owe
  # (within a cent per game, for Venmo's rounding) +30, or with a partial hint
  # ("half of 3rd ticket") an amount below what one game owes +25. Two equally
  # likely games, or paying more than is owed, cost 40.
  #
  # A payment settles automatically only at the threshold (85) with a unique
  # answer and an amount that fits. Anything else goes to review with a
  # suggestion. Outgoing payments are never settled automatically.
  class Matcher
    Candidate = Data.define(:game, :score, :reasons)

    def initialize(threshold: AppSetting.get("settlement.auto_match_min").to_i)
      @threshold = threshold
    end

    def run(payments = PartnerPayment.where(status: "unmatched").order(:occurred_on, :id))
      payments.map { |payment| match(payment) }
    end

    def match(payment)
      return :skipped unless payment.status == "unmatched"

      @ledger = Ledger.new
      season = Season.where(settlement_tracked: true).order(:year).last
      parsed = MemoParser.parse(payment.raw_name.presence || payment.memo, season: season, aliases: aliases)
      category = PaymentClassifier.call(payment, parsed)
      payment.update!(category: category) if payment.category != category && payment.category == "unknown"

      if payment.possible_duplicate_of_id
        review(payment, 0, [ "looks like a duplicate of another payment" ], [])
      elsif !payment.incoming?
        outgoing(payment, category)
      else
        incoming(payment, parsed, category)
      end
    end

    private

    def aliases
      @aliases ||= TeamAliases.table
    end

    def outgoing(payment, category)
      if category == "settlement"
        review(payment, 0, [ "money from #{Settlements.owner_name} to #{Settlements.partner_first_name} about tickets: check whether a game's payout went to #{Settlements.owner_name}" ], [])
      else
        Allocator.set_status!(payment, "ignored", category: category,
                              note: category == "cost_share" ? "season invoice installment" : "not about ticket sales")
        :ignored
      end
    end

    def incoming(payment, parsed, category)
      open = @ledger.balances.select { |b| b.outstanding_cents > b.tolerance }
      references = parsed.references.select { |r| r.team_ids.any? || r.date }

      if references.empty?
        exact = open.select { |b| (b.outstanding_cents - payment.amount_cents).abs <= b.tolerance }
        if category != "settlement" && exact.empty?
          Allocator.set_status!(payment, "ignored", category: "unrelated", note: "no ticket words and no game owes this amount")
          return :ignored
        end
        return subset_suggestion(payment, open)
      end

      picks = references.map { |ref| best_candidate(ref, payment) }
      games = picks.filter_map { |p| p[:best]&.game }.uniq
      reasons = picks.flat_map { |p| p[:best]&.reasons || [ "couldn't find the game in “#{parsed.memo}”" ] }
      if games.size < references.size
        return review(payment, 20, reasons, [])
      end

      balances = games.map { |g| @ledger.for_game(g) }
      if balances.any?(&:nil?)
        # A game it names has no sale recorded yet: wait for it (rematched when
        # the sale is entered).
        payment.update!(match_details: { "waiting" => "for the sale to be recorded", "games" => games.map(&:id) })
        return :waiting
      end

      score = (picks.sum { |p| p[:best].score }.to_f / picks.size)
      score -= 40 if picks.any? { |p| p[:ambiguous] }
      owed = balances.sum(&:outstanding_cents)
      tolerance = [ 1, balances.size ].max
      allocations = nil

      if (owed - payment.amount_cents).abs <= tolerance && owed.positive?
        score += 30
        allocations = spread(balances, payment.amount_cents)
        reasons << "amount matches what #{games.size == 1 ? "that game owes" : "those games owe"}"
      elsif balances.size == 1 && references.first.partial && payment.amount_cents < owed
        score += 25
        allocations = [ [ games.first, payment.amount_cents ] ]
        reasons << "part payment for one game, as the memo says"
      elsif payment.amount_cents > owed
        score -= 40
        reasons << "more than #{games.size == 1 ? "that game owes" : "those games owe"} (#{fmt(owed)} left)"
      else
        reasons << "less than owed (#{fmt(owed)} left) with no note saying it's partial"
      end

      score = score.clamp(0, 100).round
      suggestion = allocations || balances.map { |b| [ b.game, [ b.outstanding_cents, payment.amount_cents ].min ] }
      if allocations && score >= @threshold && picks.none? { |p| p[:ambiguous] }
        allocations.each do |game, cents|
          Allocator.allocate!(payment, game, cents, method: "auto", confidence: score,
                              reason: "memo “#{parsed.memo}”: #{reasons.uniq.join('; ')}")
        end
        payment.update!(match_confidence: score, match_details: details(score, reasons, allocations))
        :auto
      else
        review(payment, score, reasons, suggestion)
      end
    end

    # Best game for one memo reference.
    def best_candidate(ref, payment)
      games = Game.where(season: Season.where(settlement_tracked: true)).includes(:opponent, tickets: :buyer).to_a
      games = games.select { |g| ref.team_ids.include?(g.opponent_id) } if ref.team_ids.any?
      games = games.select { |g| g.game_type == "preseason" } if ref.preseason && games.any?(&:preseason?)
      games = games.select { |g| g.game_type == "playoff" } if ref.playoff && games.any?(&:playoff?)
      games = games.select { |g| g.series_game_number == ref.game_number } if ref.game_number && games.any? { |g| g.series_game_number == ref.game_number }

      candidates = games.filter_map do |game|
        score = 0
        reasons = []
        if ref.team_ids.any?
          score += 35
          reasons << "names #{game.opponent.name}"
        end
        if ref.date
          gap = (game.game_date - ref.date).abs
          next if gap > 3

          score += gap <= 1 ? 30 : 15
          reasons << "date #{ref.date.strftime('%-m/%-d')}"
        elsif ref.team_ids.any?
          next unless (payment.occurred_on - WINDOW_BEFORE..payment.occurred_on + WINDOW_AFTER).cover?(game.game_date)
        end
        if (ref.preseason || ref.playoff || ref.game_number) && games.size == 1
          score += 20
          reasons << (ref.preseason ? "preseason" : "playoff game")
        end
        if ref.buyer && game.tickets.any? { |t| t.buyer&.name.to_s.downcase.start_with?(ref.buyer.downcase) }
          score += 5
          reasons << "sold to #{ref.buyer}"
        end
        Candidate.new(game: game, score: score, reasons: reasons)
      end

      owed = candidates.select { |c| (b = @ledger.for_game(c.game)) && b.outstanding_cents > b.tolerance }
      pool = owed.any? ? owed : candidates
      if ref.date.nil? && ref.team_ids.any? && owed.size == 1
        only = owed.first
        pool = [ Candidate.new(game: only.game, score: only.score + 10, reasons: only.reasons + [ "the only #{only.game.opponent.name} game still owed" ]) ]
      end
      ranked = pool.sort_by { |c| [ -c.score, (c.game.game_date - payment.occurred_on).abs ] }
      { best: ranked.first, ambiguous: ranked.size > 1 && ranked[1].score > ranked.first.score - 20 }
    end

    WINDOW_BEFORE = 60
    WINDOW_AFTER = 120

    # Spread a payment over games' balances; any rounding cent goes on the last.
    def spread(balances, cents)
      parts = balances.map { |b| [ b.game, b.outstanding_cents ] }
      parts[-1] = [ parts[-1][0], parts[-1][1] + (cents - parts.sum(&:last)) ]
      parts
    end

    # No game named: look for exactly one set of up to 4 owed games that adds
    # up to the payment. Only ever a suggestion.
    def subset_suggestion(payment, open)
      near = open.sort_by { |b| (b.game.game_date - payment.occurred_on).abs }.first(12)
      fits = (1..[ 4, near.size ].min).flat_map { |n| near.combination(n).to_a }
                                     .select { |set| (set.sum(&:outstanding_cents) - payment.amount_cents).abs <= set.size }
      if fits.size == 1
        review(payment, 50, [ "no game named; #{fits.first.map { |b| b.game.opponent.name }.to_sentence} add up to this amount" ],
               fits.first.map { |b| [ b.game, b.outstanding_cents ] })
      else
        review(payment, 0, [ fits.empty? ? "no game named, and no set of owed games adds up to this amount" : "no game named; several combinations of games fit" ], [])
      end
    end

    def review(payment, score, reasons, suggestion)
      payment.update!(status: "needs_review", match_confidence: score.round, match_details: details(score.round, reasons, suggestion))
      :review
    end

    def details(score, reasons, allocations)
      { "score" => score, "reasons" => reasons.uniq,
        "suggestion" => allocations.map { |game, cents| { "game_id" => game.id, "cents" => cents } } }
    end

    def fmt(cents)
      ActiveSupport::NumberHelper.number_to_currency(cents / 100.0)
    end
  end
end
