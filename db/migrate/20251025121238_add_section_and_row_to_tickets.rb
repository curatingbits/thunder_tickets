class AddSectionAndRowToTickets < ActiveRecord::Migration[8.0]
  def change
    add_column :tickets, :section, :string
    add_column :tickets, :row, :string
  end
end
