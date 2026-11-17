# A listing seen in a scan, exactly as read, and how the engine treated it.
class MarketObservation < ApplicationRecord
  belongs_to :market_snapshot

  EXCLUSION_LABELS = {
    "primary" => "Standard Admission (team's own price)",
    "unknown_row" => "row not recognized",
    "courtside" => "courtside club row",
    "placeholder" => "$1,000+ and 3x our section's median",
    "far_above" => "far above our section's prices",
    "far_below" => "far below our section's prices",
    "iqr_high" => "far above the rest",
    "iqr_low" => "far below the rest",
    "ours" => "our own listing"
  }.freeze

  TIER_LABELS = { 1 => "Our row", 2 => "Our section, nearby rows", 3 => "Next-door sections", 4 => "Rest of our section" }.freeze

  SEATS_IN_LABEL = /\[Seats (\d+)-(\d+)\]/

  def readonly?
    persisted?
  end

  def kept?
    excluded_reason.nil?
  end

  # The seats the research read for this listing, or nil when only the row
  # is known. Scans from before the seats column kept them in the label, as
  # the reader appends them ("... $151.88 [Seats 6-7]").
  def seat_numbers
    return seats if seats.present?

    from, to = raw_label.to_s.match(SEATS_IN_LABEL)&.captures&.map(&:to_i)
    (from..to).to_a if from && to && from.positive? && to >= from && to - from <= 20
  end
end
