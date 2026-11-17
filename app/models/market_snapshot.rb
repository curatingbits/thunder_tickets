# One game's market in one run, and what the engine made of it. Immutable:
# only the invalidation fields can change, so history is never rewritten.
class MarketSnapshot < ApplicationRecord
  belongs_to :import_run
  belongs_to :game
  belongs_to :previous_snapshot, class_name: "MarketSnapshot", optional: true
  has_many :observations, -> { order(:position) }, class_name: "MarketObservation", dependent: :restrict_with_error

  attr_readonly(*(column_names - %w[id invalidated_at invalidation_reason]))

  scope :valid, -> { where(invalidated_at: nil) }
  scope :latest_first, -> { order(captured_at: :desc, id: :desc) }

  STRATEGY_LABELS = { "competitive" => "Competitive", "market" => "Market", "premium" => "Premium" }.freeze

  # Latest valid snapshot per game, in one query.
  def self.latest_by_game(game_ids)
    valid.where(game_id: game_ids).latest_first.to_a.uniq(&:game_id).index_by(&:game_id)
  end

  def confidence_now(now = Time.current)
    Market::Confidence.total(confidence_breakdown, captured_at, now: now, fee_verified: fee_verified)
  end

  def confidence_label(now = Time.current)
    Market::Confidence.label(confidence_now(now))
  end

  # fresh < 3 days, aging 3-8, stale after.
  def freshness(now = Time.current)
    age = now - captured_at
    if age < 3.days then :fresh
    elsif age <= 8.days then :aging
    else :stale
    end
  end

  def insufficient?
    market_value.nil?
  end

  def list_price_for(all_in, rounding: :round)
    Market::FeeModel.list_price(all_in.to_f, buyer_fee_multiplier.to_f, rounding: rounding)
  end

  def recommended_all_in
    { "competitive" => competitive_price, "market" => market_value, "premium" => premium_price }[recommended_strategy]
  end
end
