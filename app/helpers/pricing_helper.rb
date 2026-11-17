module PricingHelper
  ASSESSMENTS = {
    "overpriced" => [ "Overpriced", :warning, "↑" ],
    "underpriced" => [ "Underpriced", :warning, "↓" ],
    "competitive" => [ "Competitive", :positive, nil ],
    "not_listed" => [ "Not listed", :warning, nil ],
    "needs_verification" => [ "Verify listing", :highlight, nil ],
    "insufficient_data" => [ "Insufficient data", :neutral, nil ],
    "no_data" => [ "No market data", :neutral, nil ]
  }.freeze

  def assessment_chip(assessment)
    return if assessment.nil?

    label, tone, arrow = ASSESSMENTS.fetch(assessment)
    status_chip([ arrow, label ].compact.join(" "), tone: tone, data: { assessment: assessment })
  end

  # Confidence is about the data, not money: no green or red.
  def confidence_chip(score)
    label = Market::Confidence.label(score)
    tone = { "High" => :info, "Medium" => :accent, "Low" => :warning, "Insufficient" => :neutral }.fetch(label)
    status_chip("#{label} · #{score}", tone: tone, title: "Confidence in the market value, 0-100")
  end

  def freshness_chip(snapshot, now: Time.current)
    return status_chip("Never scanned", tone: :neutral) unless snapshot

    tone = { fresh: :neutral, aging: :warning, stale: :alt }.fetch(snapshot.freshness(now))
    status_chip("Scanned #{time_ago_in_words(snapshot.captured_at)} ago", tone: tone, icon_name: :clock)
  end

  def dollars(amount)
    amount.nil? ? "—" : number_to_currency(amount, precision: 0)
  end

  # "$260 all-in · $214 list"
  def all_in_and_list(all_in, multiplier)
    return "—" if all_in.nil?

    "#{dollars(all_in)} all-in · #{dollars(all_in.to_f / multiplier.to_f)} list"
  end

  def strategy_label(strategy)
    MarketSnapshot::STRATEGY_LABELS[strategy] || strategy.to_s.humanize
  end
end
