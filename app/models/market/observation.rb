module Market
  # One listing as the engine sees it, before it's saved.
  Observation = Struct.new(:position, :section, :row, :row_rank, :price, :ticket_type, :raw_label,
                           :tier, :weight, :dd_equivalent_price, :excluded_reason, keyword_init: true) do
    def kept? = excluded_reason.nil?
    # Rows near ours in our section or a neighbor: what our seats compete with.
    def comparable? = kept? && !tier.nil? && tier <= 3
    def resale? = ticket_type != "standard_admission"
  end
end
