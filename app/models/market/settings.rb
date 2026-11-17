module Market
  # Everything the engine is tuned by, fixed for one analysis and saved with
  # each snapshot (settings_used) so old results stay explainable.
  Settings = Data.define(:our_section, :our_row, :comparable_sections, :near_rows, :tier2_weight, :tier3_weight,
                         :row_decay, :row_step, :placeholder_floor, :placeholder_ratio, :prior_weight, :spread,
                         :row_premium_default, :buyer_fee_multiplier, :overpriced_pct, :underpriced_pct) do
    def self.for(season)
      values = AppSetting.values
      new(
        our_section: season.seat_section.presence&.upcase || "101",
        our_row: season.seat_row.presence&.upcase || "DD",
        comparable_sections: values.fetch("pricing.comparable_sections").to_s.split(",").map { |s| s.strip.upcase }.reject(&:empty?),
        near_rows: 3,
        tier2_weight: 0.85,
        tier3_weight: 0.5,
        row_decay: 0.85,
        row_step: 0.025,
        placeholder_floor: 1000.0,
        placeholder_ratio: 3.0,
        prior_weight: values.fetch("pricing.prior_weight").to_f,
        spread: 0.10,
        row_premium_default: values.fetch("pricing.row_premium_default").to_f,
        buyer_fee_multiplier: values.fetch("pricing.buyer_fee_multiplier").to_f,
        overpriced_pct: values.fetch("pricing.overpriced_pct").to_f,
        underpriced_pct: values.fetch("pricing.underpriced_pct").to_f
      )
    end
  end
end
