# Settlement terms per season (Mark pays Duggan 50% of the payout), whether
# a season is tracked (2025-26's old gaps were set aside, so only 2026-27 on),
# who received each sale's payout, and playoff series game numbers.
class AddSettlementFields < ActiveRecord::Migration[8.1]
  class MigrationSeason < ActiveRecord::Base
    self.table_name = "seasons"
  end

  def up
    add_column :seasons, :settlement_tracked, :boolean, null: false, default: true
    add_column :seasons, :partner_split_pct, :decimal, precision: 5, scale: 2, null: false, default: 50
    add_column :tickets, :payout_received_by, :string, null: false, default: "partner"
    add_check_constraint :tickets, "payout_received_by IN ('partner', 'owner')", name: "tickets_payout_received_by"
    add_column :games, :series_game_number, :integer

    MigrationSeason.where.not(year: "2026-27").update_all(settlement_tracked: false)
  end

  def down
    remove_column :games, :series_game_number
    remove_check_constraint :tickets, name: "tickets_payout_received_by"
    remove_column :tickets, :payout_received_by
    remove_column :seasons, :partner_split_pct
    remove_column :seasons, :settlement_tracked
  end
end
