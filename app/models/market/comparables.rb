module Market
  # Sorts each listing by how directly it competes with our seats:
  #   tier 1  our section, our row
  #   tier 2  our section, within 3 rows   (weight 0.85 x 0.85^rows)
  #   tier 3  a neighbor section, within 3 rows (weight 0.5 x 0.85^rows)
  #   tier 4  the rest of our section: the anchor, not a comparable
  # Courtside (FL) rows, Standard Admission and unknown rows are set aside.
  # Comparables also get a row-DD-equivalent price: 2.5% up per row behind
  # ours, down per row in front (at most 7.5%).
  class Comparables
    def initialize(settings)
      @s = settings
    end

    def classify(listing)
      section = listing[:section].to_s.strip.upcase
      row = listing[:row].to_s.strip.upcase.presence
      type = listing[:ticket_type].presence || "verified_resale"
      obs = Observation.new(position: listing[:position].to_i, section: section, row: row, row_rank: RowOrder.rank(row),
                            price: listing[:price].to_f, ticket_type: type, raw_label: listing[:raw_label].to_s.first(300),
                            seats: listing[:seats].presence, tier: nil, weight: 0.0)
      return obs.tap { |o| o.excluded_reason = "primary" } if type == "standard_admission"
      return obs.tap { |o| o.excluded_reason = "unknown_row" } if obs.row_rank.nil?
      # Courtside Club rows are a different product ($1,000-$6,000 asks in
      # Kate's scrape): neither comparables nor part of the section anchor.
      return obs.tap { |o| o.excluded_reason = "courtside" } if RowOrder.courtside?(row)

      d = RowOrder.distance(row, @s.our_row)
      ours = section == @s.our_section
      if ours && d.zero?
        obs.tier = 1
        obs.weight = 1.0
      elsif ours && d.abs <= @s.near_rows
        obs.tier = 2
        obs.weight = @s.tier2_weight * (@s.row_decay**d.abs)
      elsif @s.comparable_sections.include?(section) && d.abs <= @s.near_rows
        obs.tier = 3
        obs.weight = @s.tier3_weight * (@s.row_decay**d.abs)
      elsif ours
        obs.tier = 4
      end
      obs.dd_equivalent_price = (obs.price * (1 + (@s.row_step * d))).round(2) if obs.tier && obs.tier <= 3
      obs
    end
  end
end
