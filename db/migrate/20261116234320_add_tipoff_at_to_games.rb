class AddTipoffAtToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :tipoff_at, :datetime
  end
end
