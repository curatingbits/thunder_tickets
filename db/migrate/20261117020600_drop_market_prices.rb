# market_prices was a 2025 Discovery API experiment that never stored a row
# (the API returned no section or resale prices). market_snapshots replaces
# it. Refuses to drop the table if anything was ever written to it.
class DropMarketPrices < ActiveRecord::Migration[8.1]
  def up
    count = select_value("SELECT COUNT(*) FROM market_prices").to_i
    raise "market_prices has #{count} rows; refusing to drop it" if count.positive?

    drop_table :market_prices
  end

  def down
    create_table :market_prices do |t|
      t.references :game, null: false, foreign_key: true
      t.string :section
      t.decimal :min_price, precision: 10, scale: 2
      t.decimal :max_price, precision: 10, scale: 2
      t.decimal :average_price, precision: 10, scale: 2
      t.integer :listings_count
      t.datetime :fetched_at
      t.string :event_id
      t.string :event_url
      t.timestamps
    end
    add_index :market_prices, :event_id
    add_index :market_prices, :fetched_at
  end
end
