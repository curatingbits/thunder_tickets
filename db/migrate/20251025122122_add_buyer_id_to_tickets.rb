class AddBuyerIdToTickets < ActiveRecord::Migration[8.0]
  def change
    add_reference :tickets, :buyer, null: true, foreign_key: true
  end
end
