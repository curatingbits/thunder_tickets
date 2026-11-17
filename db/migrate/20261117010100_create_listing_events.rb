# Append-only history of listing decisions: listed, repriced, verified,
# confirmed not listed, held, ended. Never updated or deleted.
class CreateListingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :listing_events do |t|
      t.references :game, null: false, foreign_key: true
      t.references :listing, foreign_key: true
      t.string :action, null: false
      t.decimal :price_before, precision: 10, scale: 2
      t.decimal :price_after, precision: 10, scale: 2
      t.string :recommended_strategy
      t.decimal :recommended_list_price, precision: 10, scale: 2
      t.text :note
      t.references :user, foreign_key: true
      t.datetime :occurred_at, null: false
      t.datetime :created_at, null: false

      t.index [ :game_id, :occurred_at ]
      t.check_constraint "action IN ('listed', 'price_changed', 'verified', 'verified_unlisted', 'held', 'ended')",
                         name: "listing_events_action"
    end
  end
end
