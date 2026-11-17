# Partner settlements: Mark pays Duggan his share (50%) of each sold game's
# payout over Venmo. The ledger says what's owed, the importer brings in
# payments read-only, the matcher pairs them with games, and every change is
# audited. Nothing here ever moves money.
module Settlements
  def self.partner_name = AppSetting.get("settlement.partner_name").to_s
  def self.partner_first_name = partner_name.split.first.to_s
  def self.owner_name = AppSetting.get("settlement.owner_name").to_s

  # Payments before this can't be for a tracked game: 90 days before the
  # first one (Mark often pays before the game).
  def self.tracking_starts_on
    first = Game.joins(:season).where(seasons: { settlement_tracked: true }).minimum(:game_date)
    first && first - 90
  end

  # Season-ticket installments start in the spring before a season, so the
  # sync reads back to March 1 of the first tracked season's first year.
  def self.cost_share_starts_on
    year = Season.where(settlement_tracked: true).filter_map { |s| s.year.to_s[/\A\d{4}/]&.to_i }.min
    year && Date.new(year, 3, 1)
  end

  # Balances mean something only once payments have been loaded: before the
  # first sync (or a payment entered by hand), every sold game would look unpaid.
  def self.synced?
    PartnerPayment.exists? || ImportRun.where(kind: "payment_sync", status: "completed").exists?
  end
end
