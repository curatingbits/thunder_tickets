module StatusChipHelper
  # Full literal class strings so Tailwind's scanner sees every one; never
  # build these by interpolating a color name.
  CHIP_TONES = {
    positive: "bg-positive/15 text-positive border-positive/40",
    negative: "bg-negative/15 text-negative border-negative/40",
    warning: "bg-warning/15 text-warning border-warning/40",
    accent: "bg-accent/15 text-accent border-accent/40",
    alt: "bg-accent-alt/15 text-accent-alt border-accent-alt/40",
    highlight: "bg-highlight/15 text-highlight border-highlight/40",
    info: "bg-info/15 text-info border-info/40",
    neutral: "bg-surface-raised text-content-dim border-subtle"
  }.freeze

  CHIP_BASE = "inline-flex items-center gap-1 px-2 py-0.5 rounded-full border text-xs font-medium whitespace-nowrap".freeze

  # A small labelled pill. The label always carries the meaning; tone and icon
  # only reinforce it, so status never depends on color alone.
  def status_chip(label, tone: :neutral, icon_name: nil, **options)
    classes = [ CHIP_BASE, CHIP_TONES.fetch(tone), options.delete(:class) ].compact.join(" ")
    tag.span(class: classes, **options) do
      safe_join([ (icon(icon_name, "h-3.5 w-3.5") if icon_name), label ].compact)
    end
  end

  # "Today", "Tomorrow", "In 5 days" for games in the next week; nothing for
  # games further out or already played. Amber when seats are still open
  # within three days: urgent, but not a loss, so never red.
  def countdown_chip(game, today: Date.current)
    days = game.days_until(today)
    return if days.negative? || days > 7

    label = case days
    when 0 then "Today"
    when 1 then "Tomorrow"
    else "In #{days} days"
    end
    tone = if game.fully_sold? then :neutral
    elsif days <= 3 then :warning
    else :accent
    end
    status_chip(label, tone: tone, icon_name: :clock, data: { countdown: days })
  end

  # Seats still to sell. A past game's open seats are simply unsold.
  def inventory_chip(game, today: Date.current)
    open = game.tickets_available
    if open.zero?
      status_chip("Sold out", tone: :positive, icon_name: :check)
    elsif game.game_date < today
      status_chip("#{open} unsold", tone: :neutral)
    elsif game.tickets_sold_count.positive?
      status_chip("#{open} left", tone: :warning)
    else
      status_chip("#{open} to sell", tone: :neutral)
    end
  end

  # "Wed, Nov 18 · 7:00 PM", or just the date when the tipoff isn't known.
  def game_when(game)
    date = game.game_date.strftime("%a, %b %-d")
    game.tipoff_at ? "#{date} · #{game.tipoff_at.strftime('%-l:%M %p')}" : date
  end
end
