class CreateTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :tickets do |t|
      t.references :game, null: false, foreign_key: true
      t.integer :seat_number
      t.decimal :sale_price
      t.datetime :sold_at
      t.string :buyer_name
      t.string :buyer_email
      t.text :notes

      t.timestamps
    end
  end
end
