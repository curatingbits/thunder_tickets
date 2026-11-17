module Market
  # Listings pasted by hand: text copied from a Ticketmaster event page
  # ("Sec 101 • Row EE … Verified Resale Ticket … $298.08", any line breaks)
  # or one "section,row,price" per line.
  module PastedListings
    LABEL = /Sec\s+(\w+)\s*[•·]\s*Row\s+(\w+)/
    PRICE = /\$\s*([\d,]+(?:\.\d{1,2})?)/
    CSV_LINE = /\A\s*(\w+)\s*[,\t]\s*(\w+)\s*[,\t]\s*\$?\s*([\d,]+(?:\.\d{1,2})?)\s*\z/

    module_function

    def parse(text)
      text = text.to_s
      starts = text.enum_for(:scan, LABEL).map { Regexp.last_match }
      listings =
        if starts.any?
          starts.each_with_index.filter_map do |match, i|
            chunk = text[match.end(0)...(starts[i + 1]&.begin(0) || text.length)]
            price = chunk[PRICE, 1] or next
            listing(match[1], match[2], price, chunk.include?("Standard Admission") ? "standard_admission" : "verified_resale",
                    "#{match[0]} #{chunk.squish}")
          end
        else
          text.lines.filter_map do |line|
            section, row, price = line.match(CSV_LINE)&.captures
            listing(section, row, price, "verified_resale", line.strip) if section
          end
        end
      listings.each_with_index { |l, i| l[:position] = i + 1 }
    end

    def listing(section, row, price, type, label)
      { section: section.upcase, row: row.upcase, price: price.delete(",").to_f, ticket_type: type, raw_label: label.first(300) }
    end
  end
end
