module Market
  # How much to trust a snapshot's market value, 0-100:
  #   depth        40  comparable weight, full at 3 tier-1-equivalents
  #   proximity    15  share of that weight from our own section
  #   consistency  15  how tightly the comparables agree
  #   anchor       10  enough listings in our section for its median
  #   coverage     10  the scan read the whole list (manual entry: 3)
  #   freshness    10  added when shown: full for 2 days, gone at 12
  # Capped at 69 (Medium) when the scan couldn't confirm the fee multiplier.
  module Confidence
    LABELS = [ [ 70, "High" ], [ 45, "Medium" ], [ 25, "Low" ], [ 0, "Insufficient" ] ].freeze

    module_function

    def breakdown(valuation, scroll_complete:, manual:)
      weight = valuation.weight
      values = valuation.comparable_values
      consistency =
        if values.size >= 3 && valuation.comp_median.to_f.positive?
          spread = (valuation.comp_p75 - valuation.comp_p25) / valuation.comp_median
          15 * (1 - (spread / 0.5)).clamp(0, 1)
        elsif values.size == 2
          a, b = values
          15 * (1 - (((a - b).abs / ((a + b) / 2.0)) / 0.5)).clamp(0, 1)
        else
          0
        end
      {
        "depth" => (40 * [ weight / 3.0, 1 ].min).round(1),
        "proximity" => (weight.positive? ? 15 * valuation.near_weight / weight : 0).round(1),
        "consistency" => consistency.round(1),
        "anchor" => if valuation.section_count >= 5 then 10 elsif valuation.section_count >= 3 then 5 else 0 end,
        "coverage" => if manual then 3 elsif scroll_complete then 10 else 4 end
      }
    end

    def freshness(captured_at, now)
      age = (now - captured_at) / 1.day
      return 10.0 if age <= 2

      (10 * (1 - ((age - 2) / 10.0))).clamp(0, 10)
    end

    def total(breakdown, captured_at, now: Time.current, fee_verified: true)
      score = (breakdown.values.sum + freshness(captured_at, now)).round
      fee_verified ? score : [ score, 69 ].min
    end

    def label(score)
      LABELS.find { |floor, _| score >= floor }.last
    end
  end
end
