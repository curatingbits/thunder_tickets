# Where the seats are, per season, instead of "101"/"DD" hardcoded in the
# sale forms. Every season so far has been Section 101, Row DD.
class AddSeatRowToSeasons < ActiveRecord::Migration[8.1]
  class MigrationSeason < ActiveRecord::Base
    self.table_name = "seasons"
  end

  def up
    add_column :seasons, :seat_row, :string, default: "DD"
    MigrationSeason.where(seat_section: [ nil, "" ]).update_all(seat_section: "101")
    MigrationSeason.where(seat_row: [ nil, "" ]).update_all(seat_row: "DD")
  end

  def down
    remove_column :seasons, :seat_row
  end
end
