# Bearer tokens for the workstation skills. Only a SHA-256 digest is stored;
# the token itself is shown once, when it's created.
class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.string :scopes, null: false, default: ""
      t.datetime :last_used_at
      t.datetime :expires_at
      t.datetime :revoked_at
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps

      t.index :token_digest, unique: true
    end
  end
end
