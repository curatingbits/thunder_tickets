module Market
  # Listings the engine sets aside, each with the reason saved:
  #   placeholder  >= $1,000 and >= 3x our section's median: a seller parking
  #                a listing, not a real ask (Kate saw $1,094-$1,154 at four
  #                games). Relative, so real playoff prices survive.
  #   far_above/   a comparable over 2.5x (or under 0.5x) our section's
  #   far_below    median, row-adjusted. Most games have under 5 comparables,
  #                too few for IQR, and one $832 neighbor-section ask (Jazz
  #                1/2) otherwise dragged the premium price up 50%.
  #   iqr_high/low outside 1.5x the interquartile range of the comparables,
  #                once there are at least 5 of them.
  #   ours         a row-DD listing at our own all-in price: it's us.
  # The section anchor isn't IQR-trimmed: its median is already robust, and
  # trimming it would throw out legitimately pricier front rows.
  module Outliers
    FAR_ABOVE = 2.5
    FAR_BELOW = 0.5

    module_function

    def apply(observations, settings, our_all_in: nil)
      section = observations.select { |o| o.kept? && o.section == settings.our_section }.map(&:price)
      if (median = Stats.median(section))
        observations.each do |o|
          next unless o.kept? && o.price >= settings.placeholder_floor && o.price >= settings.placeholder_ratio * median

          o.excluded_reason = "placeholder"
        end
      end

      if median && section.size >= 3
        observations.select(&:comparable?).each do |o|
          if o.dd_equivalent_price > FAR_ABOVE * median then o.excluded_reason = "far_above"
          elsif o.dd_equivalent_price < FAR_BELOW * median then o.excluded_reason = "far_below"
          end
        end
      end

      iqr!(observations.select(&:comparable?))

      if our_all_in
        ours = observations.find { |o| o.comparable? && o.tier == 1 && (o.price - our_all_in).abs <= 1.0 }
        ours&.excluded_reason = "ours"
      end
      observations
    end

    def iqr!(set)
      return if set.size < 5

      values = set.map(&:dd_equivalent_price).sort
      q1 = Stats.quantile(values, 0.25)
      q3 = Stats.quantile(values, 0.75)
      fence = 1.5 * (q3 - q1)
      set.each do |o|
        if o.dd_equivalent_price > q3 + fence
          o.excluded_reason = "iqr_high"
        elsif o.dd_equivalent_price < q1 - fence
          o.excluded_reason = "iqr_low"
        end
      end
    end
  end
end
