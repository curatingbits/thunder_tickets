# What the market looked like for one game in one run, and what the pricing
# engine made of it. Immutable once written: history is never rewritten.
class CreateMarketSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :market_snapshots do |t|
      t.references :import_run, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.datetime :captured_at, null: false
      t.integer :days_to_game, null: false

      # The scan
      t.string :event_id
      t.string :event_url
      t.string :event_title
      t.integer :quantity_filter, null: false, default: 2
      t.string :price_basis, null: false, default: "all_in_ex_tax"
      t.integer :event_total_listings
      t.integer :captured_count, null: false, default: 0
      t.boolean :scroll_complete, null: false, default: true
      t.string :payload_digest, null: false
      t.string :engine_version, null: false
      t.json :settings_used, null: false, default: {}

      # Comparables
      t.integer :tier1_count, null: false, default: 0
      t.integer :tier2_count, null: false, default: 0
      t.integer :tier3_count, null: false, default: 0
      t.integer :section_count, null: false, default: 0
      t.integer :excluded_count, null: false, default: 0
      t.decimal :comp_weight, precision: 8, scale: 3, null: false, default: 0
      t.decimal :comp_min, precision: 10, scale: 2
      t.decimal :comp_p25, precision: 10, scale: 2
      t.decimal :comp_median, precision: 10, scale: 2
      t.decimal :comp_mean, precision: 10, scale: 2
      t.decimal :comp_p75, precision: 10, scale: 2
      t.decimal :comp_max, precision: 10, scale: 2
      t.decimal :section_min, precision: 10, scale: 2
      t.decimal :section_median, precision: 10, scale: 2
      t.decimal :section_max, precision: 10, scale: 2
      t.decimal :near_raw_median, precision: 10, scale: 2
      t.decimal :row_premium, precision: 6, scale: 3
      t.string :row_premium_source
      t.decimal :primary_min_price, precision: 10, scale: 2
      t.json :distribution, null: false, default: {}

      # Fees
      t.decimal :buyer_fee_multiplier, precision: 6, scale: 4, null: false
      t.decimal :fee_evidence_share, precision: 5, scale: 3
      t.boolean :fee_verified, null: false, default: false

      # Recommendation (prices are buyer all-in per ticket)
      t.decimal :competitive_price, precision: 10, scale: 2
      t.decimal :market_value, precision: 10, scale: 2
      t.decimal :premium_price, precision: 10, scale: 2
      t.string :recommended_strategy
      t.decimal :recommended_list_price, precision: 10, scale: 2
      t.json :rationale, null: false, default: []
      t.integer :confidence, null: false, default: 0
      t.json :confidence_breakdown, null: false, default: {}

      # Our listing when captured
      t.decimal :our_ask_price, precision: 10, scale: 2
      t.string :our_ask_basis
      t.decimal :our_all_in, precision: 10, scale: 2
      t.string :assessment
      t.boolean :observed_our_listing, null: false, default: false

      # Trend
      t.references :previous_snapshot, foreign_key: { to_table: :market_snapshots }
      t.decimal :market_value_change_pct, precision: 7, scale: 2
      t.integer :section_count_change

      t.datetime :invalidated_at
      t.string :invalidation_reason
      t.datetime :created_at, null: false

      t.index [ :import_run_id, :game_id ], unique: true
      t.index [ :game_id, :captured_at ]
    end
  end
end
