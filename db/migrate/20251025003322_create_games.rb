class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.references :season, null: false, foreign_key: true
      t.integer :game_number
      t.date :game_date
      t.references :opponent, null: false, foreign_key: { to_table: :teams }
      t.decimal :cost_per_ticket
      t.decimal :parking_cost
      t.string :game_type
      t.string :playoff_round

      t.timestamps
    end
  end
end
