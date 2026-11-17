module Market
  # Market value for our seats, all-in per ticket.
  #
  # Comparables near row DD are sparse (Kate's 35 games: one row-DD listing,
  # 0-3 nearby rows per game), so the weighted comparables are blended with a
  # prior: our section's median x the near-DD row premium, weighted as if it
  # were `prior_weight` comparables. With no comparables the prior stands
  # alone; with plenty, they dominate. Fewer than 3 section listings and no
  # comparables is not enough to say anything.
  #
  # Ceiling: with 3+ listings in our section, market value can't top the
  # highest of our section's asks and the near-DD comparables (row-adjusted).
  # Front rows outrank ours, so if nothing in the section asks more, our seats
  # aren't worth more; the prior alone overshot whenever the section was
  # already full of near-DD rows (Pistons 12/22: $449 vs a $371 top ask).
  # Competitive stays 10% under the ceiling, premium at most 10% over.
  class Valuation
    Result = Data.define(:insufficient, :weight, :near_weight, :competitive, :market, :premium,
                         :comp_min, :comp_p25, :comp_median, :comp_mean, :comp_p75, :comp_max,
                         :section_count, :section_min, :section_median, :section_max, :near_raw_median,
                         :prior, :comparable_values)

    def self.call(observations, settings, row_premium:)
      comps = observations.select(&:comparable?)
      pairs = comps.map { |o| [ o.dd_equivalent_price, o.weight ] }
      weight = pairs.sum(&:last)
      near_weight = comps.select { |o| o.tier <= 2 }.sum(&:weight)
      section = observations.select { |o| o.kept? && o.section == settings.our_section }.map(&:price).sort
      anchor = Stats.quantile(section, 0.5)
      prior = anchor && anchor * row_premium
      wq = ->(q) { Stats.weighted_quantile(pairs, q) }
      raw = comps.map(&:price)

      base = { weight: weight, near_weight: near_weight,
               comp_min: raw.min, comp_p25: wq.(0.25), comp_median: wq.(0.5), comp_mean: Stats.weighted_mean(pairs),
               comp_p75: wq.(0.75), comp_max: raw.max,
               section_count: section.size, section_min: section.first, section_median: anchor, section_max: section.last,
               near_raw_median: Stats.median(comps.select { |o| o.tier <= 2 }.map(&:price)),
               prior: prior, comparable_values: pairs.map(&:first) }

      if (weight.zero? && section.size < 3) || (weight.zero? && prior.nil?)
        return Result.new(insufficient: true, competitive: nil, market: nil, premium: nil, **base)
      end

      k = settings.prior_weight
      blend = lambda do |x, px|
        if weight.positive? && px then ((weight * x) + (k * px)) / (weight + k)
        elsif weight.positive? then x
        else px
        end
      end
      prices = [
        blend.(wq.(0.25), prior && prior * (1 - settings.spread)),
        blend.(wq.(0.5), prior),
        blend.(wq.(0.75), prior && prior * (1 + settings.spread))
      ].sort
      if section.size >= 3
        ceiling = ([ section.last ] + comps.select { |o| o.tier <= 2 }.map(&:dd_equivalent_price)).max
        caps = [ ceiling * (1 - settings.spread), ceiling, ceiling * (1 + settings.spread) ]
        prices = prices.zip(caps).map { |price, cap| [ price, cap ].min }.sort
      end
      prices = prices.map { |p| p.round(2) }

      Result.new(insufficient: false, competitive: prices[0], market: prices[1], premium: prices[2], **base)
    end
  end
end
