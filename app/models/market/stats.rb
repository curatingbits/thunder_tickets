module Market
  module Stats
    module_function

    def median(values)
      quantile(values.sort, 0.5)
    end

    # Linear interpolation between order statistics (the common "type 7").
    def quantile(sorted, q)
      return if sorted.empty?

      h = (sorted.size - 1) * q
      lo = h.floor
      hi = h.ceil
      sorted[lo] + ((sorted[hi] - sorted[lo]) * (h - lo))
    end

    # Weighted quantile of [value, weight] pairs: each value sits at the
    # middle of its share of the total weight, interpolated between.
    def weighted_quantile(pairs, q)
      pairs = pairs.select { |_, w| w.positive? }.sort_by(&:first)
      return if pairs.empty?

      total = pairs.sum(&:last)
      cumulative = 0.0
      points = pairs.map do |value, weight|
        cumulative += weight
        [ (cumulative - (weight / 2.0)) / total, value ]
      end
      return points.first.last if q <= points.first.first
      return points.last.last if q >= points.last.first

      points.each_cons(2) do |(s0, v0), (s1, v1)|
        return v0 + ((v1 - v0) * (q - s0) / (s1 - s0)) if q <= s1
      end
    end

    def weighted_mean(pairs)
      total = pairs.sum(&:last)
      return if total.zero?

      pairs.sum { |value, weight| value * weight } / total
    end
  end
end
