class CreateSeasons < ActiveRecord::Migration[8.0]
  def change
    create_table :seasons do |t|
      t.string :year
      t.decimal :total_season_cost
      t.boolean :is_current
      t.integer :num_seats

      t.timestamps
    end
    add_index :seasons, :year, unique: true
  end
end
