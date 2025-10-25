class AddInvitationFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :active, :boolean, default: true, null: false
    add_column :users, :invitation_token, :string
    add_column :users, :invitation_sent_at, :datetime
    add_column :users, :invitation_accepted_at, :datetime

    add_index :users, :invitation_token, unique: true
    add_index :users, :active
  end
end
