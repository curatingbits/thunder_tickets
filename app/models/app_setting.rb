# Tunable thresholds. Every setting has a default in DEFINITIONS; a row is
# stored only once someone changes it, and nil means "use the default".
class AppSetting < ApplicationRecord
  Definition = Data.define(:key, :type, :default, :label, :help)

  DEFINITIONS = [
    Definition.new("pricing.overpriced_pct", :decimal, 15,
                   "Overpriced when our price is above market by more than (%)", nil),
    Definition.new("pricing.underpriced_pct", :decimal, 15,
                   "Underpriced when our price is below market by more than (%)", nil),
    Definition.new("pricing.buyer_fee_multiplier", :decimal, BigDecimal("1.215"),
                   "Buyer's all-in price ÷ our list price",
                   "Re-checked on every scan; this is the fallback when a scan can't confirm it."),
    Definition.new("pricing.seller_fee_pct", :decimal, nil,
                   "Ticketmaster seller fee (%)",
                   "Leave blank until known. Payouts are estimated only from this or from sales linked to listings."),
    Definition.new("pricing.comparable_sections", :string, "102,120",
                   "Sections next to ours (comma-separated)", nil),
    Definition.new("pricing.row_premium_default", :decimal, BigDecimal("1.45"),
                   "Rows near ours vs the section's typical price",
                   "Used until 8 games of history let the app measure it."),
    Definition.new("pricing.prior_weight", :decimal, 2,
                   "How strongly sparse comparables lean on the section's typical price", nil)
  ].index_by(&:key).freeze

  belongs_to :updated_by, class_name: "User", optional: true

  validates :key, presence: true, uniqueness: true, inclusion: { in: DEFINITIONS.keys }

  def self.get(key)
    definition = DEFINITIONS.fetch(key)
    raw = stored_values[key]
    raw.nil? ? definition.default : cast(definition, raw)
  end

  def self.set(key, value, user: nil)
    definition = DEFINITIONS.fetch(key)
    setting = find_or_initialize_by(key: key)
    setting.update!(value: value.to_s.strip.presence && cast(definition, value).to_s, updated_by: user)
    Current.app_settings = nil
  end

  # Every stored value in one query, cached for the request.
  def self.stored_values
    Current.app_settings ||= pluck(:key, :value).to_h
  end

  def self.cast(definition, value)
    return if value.nil? || value.to_s.strip.empty?

    case definition.type
    when :decimal then BigDecimal(value.to_s)
    when :integer then Integer(value.to_s)
    else value.to_s.strip
    end
  end
end
