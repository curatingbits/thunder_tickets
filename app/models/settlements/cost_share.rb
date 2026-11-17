module Settlements
  # Duggan's half of the season-ticket invoice, which he pays Mark in
  # installments ("Thunder 26/27"). An installment belongs to the season its
  # memo names; one that names none counts toward the season whose spring it
  # falls in (March to the next February). Refunds from Mark count against.
  class CostShare
    Result = Data.define(:season, :invoice_cents, :share_cents, :payments) do
      def paid_cents = payments.sum(&:signed_for_cost_share)
      def remaining_cents = share_cents - paid_cents
      def paid_pct = share_cents.positive? ? (paid_cents * 100.0 / share_cents).clamp(0, 100).round : 0
    end

    def self.for(season)
      return if season.total_season_cost.to_f <= 0

      invoice = (season.total_season_cost.to_d * 100).round.to_i
      share = Ledger.half_up(invoice * (100 - season.partner_split_pct) / 100)
      start_year = season.year.to_s[/\A\d{4}/].to_i
      payments = PartnerPayment.where(category: "cost_share").order(:occurred_on, :id).select do |p|
        (PaymentClassifier.season_start_year(p.memo) || spring_year(p.occurred_on)) == start_year
      end
      Result.new(season: season, invoice_cents: invoice, share_cents: share, payments: payments)
    end

    def self.spring_year(date) = date.month >= 3 ? date.year : date.year - 1
  end
end
