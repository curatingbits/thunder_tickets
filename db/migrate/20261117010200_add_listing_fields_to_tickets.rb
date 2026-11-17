# Links a sale to the listing it sold from (and that listing's price at the
# time, so seller fees can later be measured from real payouts), and records
# when the tickets reached the buyer.
class AddListingFieldsToTickets < ActiveRecord::Migration[8.1]
  class MigrationTicket < ActiveRecord::Base
    self.table_name = "tickets"
  end

  class MigrationGame < ActiveRecord::Base
    self.table_name = "games"
  end

  class MigrationBuyer < ActiveRecord::Base
    self.table_name = "buyers"
  end

  def up
    add_column :tickets, :transferred_at, :datetime
    add_reference :tickets, :listing, foreign_key: true
    add_column :tickets, :list_price_at_sale, :decimal, precision: 10, scale: 2

    zone = ActiveSupport::TimeZone["America/Chicago"]
    today = zone.today

    # Tickets for games already played reached their buyers by tipoff.
    MigrationGame.where("game_date < ?", today).find_each do |game|
      delivered = game.tipoff_at || zone.local(game.game_date.year, game.game_date.month, game.game_date.day, 19)
      MigrationTicket.where(game_id: game.id, transferred_at: nil).update_all(transferred_at: delivered)
    end

    # Ticketmaster resale delivers the tickets itself when they sell.
    marketplace = MigrationBuyer.where("LOWER(name) = ?", "ticketmaster").pluck(:id)
    MigrationTicket.where(buyer_id: marketplace, transferred_at: nil).find_each do |ticket|
      ticket.update_columns(transferred_at: ticket.sold_at || ticket.created_at)
    end
  end

  def down
    remove_column :tickets, :list_price_at_sale
    remove_reference :tickets, :listing, foreign_key: true
    remove_column :tickets, :transferred_at
  end
end
