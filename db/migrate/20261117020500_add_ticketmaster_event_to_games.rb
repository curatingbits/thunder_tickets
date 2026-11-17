class AddTicketmasterEventToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :ticketmaster_event_id, :string
    add_column :games, :ticketmaster_url, :string
    add_index :games, :ticketmaster_event_id, unique: true, where: "ticketmaster_event_id IS NOT NULL"
    add_reference :listing_events, :market_snapshot, foreign_key: true
  end
end
