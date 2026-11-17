# Our own listings (and holds) for a game's seats. A listing records what we
# asked and when someone last confirmed it's still up; it never syncs with
# Ticketmaster.
class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.references :game, null: false, foreign_key: true
      t.string :kind, null: false, default: "listing"
      t.json :seat_numbers, null: false, default: []
      t.string :platform
      t.references :account_user, foreign_key: { to_table: :users }
      t.decimal :ask_price, precision: 10, scale: 2
      t.string :ask_price_basis, null: false, default: "seller_list"
      t.string :status, null: false, default: "active"
      t.string :end_reason
      t.datetime :verified_at
      t.references :verified_by, foreign_key: { to_table: :users }
      t.datetime :ended_at
      t.text :notes
      t.timestamps

      t.index [ :game_id, :status ]
      t.check_constraint "kind IN ('listing', 'hold')", name: "listings_kind"
      t.check_constraint "status IN ('active', 'ended')", name: "listings_status"
      t.check_constraint "ask_price_basis IN ('seller_list', 'buyer_all_in')", name: "listings_ask_price_basis"
      t.check_constraint "ask_price IS NULL OR ask_price > 0", name: "listings_ask_price_positive"
    end
  end
end
