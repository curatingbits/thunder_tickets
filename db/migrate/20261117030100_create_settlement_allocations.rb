# How much of a payment settles which game. Signed cents from Duggan's side:
# positive when Mark paid Duggan, negative when Duggan paid Mark. Never
# deleted: a correction voids the old row (with a reason) and adds a new one.
class CreateSettlementAllocations < ActiveRecord::Migration[8.1]
  def change
    create_table :settlement_allocations do |t|
      t.references :partner_payment, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.string :method, null: false
      t.integer :confidence
      t.string :reason, null: false
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :voided_at
      t.references :voided_by, foreign_key: { to_table: :users }
      t.string :void_reason
      t.references :replaces, foreign_key: { to_table: :settlement_allocations }
      t.timestamps

      t.index [ :partner_payment_id, :game_id ], unique: true, where: "voided_at IS NULL",
                                                 name: "index_settlement_allocations_one_active_per_payment_game"
      t.check_constraint "amount_cents <> 0", name: "settlement_allocations_amount_nonzero"
      t.check_constraint "method IN ('auto', 'manual')", name: "settlement_allocations_method"
    end
  end
end
