module Market
  # Reads Kate's Ticketmaster scrape format (her 2026-11-16 run) into one
  # market-scan payload per event:
  #   { "<event url>" => { "title", "total", "count",
  #                        "listings" => [[section, row, price, label], ...] } }
  # The event date and id come from the URL (.../11-18-2026/event/0C00...).
  module ScrapeFile
    URL_DATE = %r{(\d{2})-(\d{2})-(\d{4})/event/}
    URL_EVENT = %r{/event/([0-9A-Za-z]+)}

    module_function

    def payloads(json, captured_at:)
      json.map do |url, event|
        month, day, year = url.match(URL_DATE)&.captures
        listings = Array(event["listings"]).each_with_index.map do |(section, row, price, label), i|
          { position: i + 1, section: section, row: row, price: price, raw_label: label,
            ticket_type: label.to_s.include?("Standard Admission") ? "standard_admission" : "verified_resale" }
        end
        {
          event_url: url, event_id: url[URL_EVENT, 1], event_title: event["title"].to_s.squish.first(200),
          event_date: (year && "#{year}-#{month}-#{day}"), event_total_listings: event["total"],
          scroll_complete: event["count"].to_i >= event["total"].to_i, quantity_filter: 2,
          captured_at: captured_at.iso8601, listings: listings
        }
      end
    end
  end
end
