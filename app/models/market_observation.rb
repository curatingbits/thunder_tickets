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

  def readonly?
    persisted?
  end

  def kept?
    excluded_reason.nil?
  end
end
