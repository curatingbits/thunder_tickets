# Who changed what in the money records, and why. Append-only.
class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :auditable, polymorphic: true, null: false
      t.string :action, null: false
      t.json :changeset, null: false, default: {}
      t.text :note
      t.references :user, foreign_key: true
      t.references :api_token, foreign_key: true
      t.datetime :created_at, null: false
    end
  end
end
