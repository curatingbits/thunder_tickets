module InsightsHelper
  # "+12%", "−8%", or "typical".
  def vs_typical(pct)
    return "typical" if pct.zero?

    "#{pct.positive? ? "+" : "−"}#{pct.abs}%"
  end

  # A bar out from a center line: right for above typical, left for below.
  # Decorative; the text beside it carries the number.
  def diverging_bar(pct, max)
    width = max.to_f.zero? ? 0 : (pct.abs / max.to_f * 50).clamp(0, 50).round(1)
    side = pct.negative? ? "right-1/2 rounded-l-sm" : "left-1/2 rounded-r-sm"
    tag.div(class: "relative h-2 rounded-full bg-surface-raised", aria: { hidden: true }) do
      safe_join([ tag.span(class: "absolute inset-y-0 #{side} bg-chart-series-1", style: "width: #{width}%"),
                  tag.span(class: "absolute -inset-y-0.5 left-1/2 w-px bg-muted") ])
    end
  end
end
