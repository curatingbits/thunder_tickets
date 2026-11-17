# Partner settlements: Mark pays Duggan his share (50%) of each sold game's
# payout over Venmo. The ledger says what's owed, the importer brings in
# payments read-only, the matcher pairs them with games, and every change is
# audited. Nothing here ever moves money.
module Settlements
  def self.partner_name = AppSetting.get("settlement.partner_name").to_s
  def self.partner_first_name = partner_name.split.first.to_s
  def self.owner_name = AppSetting.get("settlement.owner_name").to_s

  # Balances mean something only once payments have been loaded: before the
  # first sync (or a payment entered by hand), every sold game would look unpaid.
  def self.synced?
    PartnerPayment.exists? || ImportRun.where(kind: "payment_sync", status: "completed").exists?
  end
end
