class AddSeatSectionToSeasons < ActiveRecord::Migration[8.0]
  def change
    add_column :seasons, :seat_section, :string
  end
end
