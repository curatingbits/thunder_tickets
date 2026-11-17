module Settlements
  # What each sold game in a tracked season owes, from Duggan's side: the
  # partner's share of the payout he received, minus Duggan's share of any
  # payout Duggan received, rounded half-up per game (as Venmo does: half of
  # $869.25 is $434.63). Then what's been allocated, and the status.
  class Ledger
    Balance = Data.define(:game, :revenue_cents, :expected_cents, :allocated_cents, :allocation_count, :status) do
      def outstanding_cents = expected_cents - allocated_cents
      def tolerance = [ 1, allocation_count ].max
      def settled? = status == :paid
    end

    STATUS_LABELS = { unpaid: "Unpaid", partially_paid: "Partially paid", paid: "Paid", needs_review: "Needs review" }.freeze

    def self.expected_cents(game)
      split = game.season.partner_split_pct / 100
      by_side = game.tickets.group_by(&:payout_received_by)
      partner = cents(by_side.fetch("partner", []))
      owner = cents(by_side.fetch("owner", []))
      half_up(partner * split) - half_up(owner * split)
    end

    def self.cents(tickets)
      tickets.sum { |t| (t.sale_price * 100).round }
    end

    def self.half_up(value)
      BigDecimal(value.to_s).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    def initialize(seasons = Season.where(settlement_tracked: true))
      @seasons = Array(seasons)
    end

    def balances
      @balances ||= begin
        games = Game.where(season: @seasons).includes(:season, :opponent, :tickets).order(:game_date).to_a
        allocations = SettlementAllocation.active.where(game_id: games.map(&:id)).group_by(&:game_id)
        review_game_ids = PartnerPayment.where(status: "needs_review").flat_map { |p| suggested_game_ids(p) }.to_set
        games.filter_map do |game|
          next if game.tickets.empty? && !allocations.key?(game.id)

          expected = self.class.expected_cents(game)
          allocs = allocations.fetch(game.id, [])
          allocated = allocs.sum(&:amount_cents)
          Balance.new(game: game, revenue_cents: self.class.cents(game.tickets), expected_cents: expected,
                      allocated_cents: allocated, allocation_count: allocs.size,
                      status: status_for(expected, allocated, allocs.size, review_game_ids.include?(game.id)))
        end
      end
    end

    def for_game(game)
      balances.find { |b| b.game.id == game.id }
    end

    def totals
      {
        expected_cents: balances.sum(&:expected_cents),
        allocated_cents: balances.sum(&:allocated_cents),
        outstanding_cents: balances.sum(&:outstanding_cents),
        unpaid_games: balances.count { |b| b.status.in?(%i[unpaid partially_paid]) },
        review_games: balances.count { |b| b.status == :needs_review }
      }
    end

    private

    def status_for(expected, allocated, count, under_review)
      return :needs_review if under_review
      return :paid if (expected - allocated).abs <= [ 1, count ].max
      return :needs_review if expected.positive? ? allocated > expected : allocated < expected
      allocated.zero? ? :unpaid : :partially_paid
    end

    def suggested_game_ids(payment)
      Array(payment.match_details["suggestion"]).map { |s| s["game_id"] }
    end
  end
end
