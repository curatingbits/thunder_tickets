class CreateMarketPrices < ActiveRecord::Migration[8.0]
  def change
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
