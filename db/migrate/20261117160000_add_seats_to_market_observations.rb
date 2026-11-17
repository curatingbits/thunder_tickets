# Seat numbers the research read for a listing (it opens the listings that
# can be comparables, in rows near ours). Nil for everything else: the
# list on Ticketmaster only gives section and row.
class AddSeatsToMarketObservations < ActiveRecord::Migration[8.1]
  def change
    add_column :market_observations, :seats, :json
  end
end
