class RemoveBuyerFieldsFromTickets < ActiveRecord::Migration[8.0]
  def change
    remove_column :tickets, :buyer_name, :string
    remove_column :tickets, :buyer_email, :string
  end
end
