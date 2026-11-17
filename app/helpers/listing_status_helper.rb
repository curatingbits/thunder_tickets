module ListingStatusHelper
  LISTING_TONES = {
    transferred: :positive,
    sold: :positive,
    unsold: :neutral,
    reserved: :info,
    listed: :accent,
    partially_sold: :warning,
    not_listed: :warning,
    needs_verification: :highlight
  }.freeze

  def listing_status_chip(result)
    status_chip(result.label, tone: LISTING_TONES.fetch(result.status), data: { listing_status: result.status })
  end

  # One line of context: what's listed at what price and when someone last
  # checked, or what's missing.
  def listing_status_detail(result)
    sold = ("#{result.sold_count} sold" if result.sold_count.positive?)
    listed = ("#{result.listed_seats.size} listed at #{ask_price_text(result)}" if result.listed_seats.any?)
    checked = ("checked #{time_ago_in_words(result.verified_at)} ago" if result.verified_at)

    case result.status
    when :listed then [ listed, checked ].compact.join(" · ")
    when :partially_sold
      rest = listed || "#{result.unlisted_seats.size} not listed"
      [ sold, rest, (checked if listed) ].compact.join(" · ")
    when :not_listed then "Confirmed not listed #{time_ago_in_words(result.confirmed_unlisted_at)} ago"
    when :needs_verification
      if result.listed_seats.any?
        [ listed, checked ? "last #{checked}" : "never checked" ].join(" · ")
      else
        "No listing recorded for #{pluralize(result.unlisted_seats.size, "open seat")}"
      end
    when :reserved then "#{seat_list(result.held_seats)} held"
    when :sold then result.untransferred_count.positive? ? "#{pluralize(result.untransferred_count, "ticket")} to deliver" : "All seats sold"
    when :transferred then "All tickets delivered"
    when :unsold then "#{pluralize(result.open_seats.size, "seat")} went unsold"
    end
  end

  def ask_price_text(result)
    prices = result.ask_prices
    return "an unknown price" if prices.empty?

    text = prices.one? ? number_to_currency(prices.first) : "#{number_to_currency(prices.first)}–#{number_to_currency(prices.last)}"
    result.listings.any?(&:all_in_price?) ? "#{text} all-in" : text
  end

  def seat_list(seats)
    seats.one? ? "Seat #{seats.first}" : "Seats #{seats.to_sentence}"
  end

  def listing_event_text(event)
    case event.action
    when "listed" then "Listed at #{number_to_currency(event.price_after)}"
    when "price_changed" then "Price #{number_to_currency(event.price_before)} → #{number_to_currency(event.price_after)}"
    when "verified" then event.price_after ? "Confirmed still listed at #{number_to_currency(event.price_after)}" : "Confirmed still listed"
    when "verified_unlisted" then "Confirmed not listed"
    when "held" then "Seats held"
    when "ended" then "Ended: #{event.note.presence || "listing closed"}"
    end
  end
end
