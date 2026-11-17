# Venmo payments between Duggan and Mark, as imported (read-only) from the
# finance app or entered by hand. Amounts in integer cents. Never deleted:
# a payment that vanishes from the source is flagged, not removed.
class CreatePartnerPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :partner_payments do |t|
      t.references :import_run, foreign_key: true
      t.string :source, null: false
      t.string :external_id, null: false
      t.date :occurred_on, null: false
      t.integer :amount_cents, null: false
      t.string :direction, null: false
      t.string :counterparty
      t.text :memo
      t.string :raw_name
      t.string :account_name
      t.string :category, null: false, default: "unknown"
      t.string :status, null: false, default: "unmatched"
      t.integer :match_confidence
      t.json :match_details, null: false, default: {}
      t.references :possible_duplicate_of, foreign_key: { to_table: :partner_payments }
      t.datetime :source_missing_at
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.text :review_note
      t.json :raw, null: false, default: {}
      t.timestamps

      t.index [ :source, :external_id ], unique: true
      t.index [ :status, :occurred_on ]
      t.index [ :occurred_on, :amount_cents, :direction ]
      t.check_constraint "amount_cents > 0", name: "partner_payments_amount_positive"
      t.check_constraint "direction IN ('incoming', 'outgoing')", name: "partner_payments_direction"
      t.check_constraint "category IN ('settlement', 'cost_share', 'unrelated', 'unknown')", name: "partner_payments_category"
      t.check_constraint "status IN ('unmatched', 'partially_matched', 'matched', 'needs_review', 'ignored')", name: "partner_payments_status"
    end
  end
end
