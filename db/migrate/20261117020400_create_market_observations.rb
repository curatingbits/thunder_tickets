# Each listing seen in a scan, exactly as read, plus how the engine treated
# it. Immutable. No content de-duplication: two sellers with the same
# section, row and price are real supply. Replays are caught by the
# snapshot's payload_digest.
class CreateMarketObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :market_observations do |t|
      t.references :market_snapshot, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :section, null: false
      t.string :row
      t.integer :row_rank
      t.decimal :price, precision: 10, scale: 2, null: false
      t.string :ticket_type, null: false, default: "verified_resale"
      t.integer :tier
      t.decimal :weight, precision: 6, scale: 4, null: false, default: 0
      t.decimal :dd_equivalent_price, precision: 10, scale: 2
      t.string :excluded_reason
      t.string :raw_label
      t.datetime :created_at, null: false

      t.index [ :market_snapshot_id, :position ], unique: true
    end
  end
end
