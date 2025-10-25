class CreateBuyers < ActiveRecord::Migration[8.0]
  def change
    create_table :buyers do |t|
      t.string :name
      t.string :email
      t.text :notes

      t.timestamps
    end

    add_index :buyers, :name
    add_index :buyers, :email
  end
end
