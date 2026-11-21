# Update prices on the Pricing page: a request for Duggan's computer to run
# the Ticketmaster research now. At most one waits at a time.
class CreateResearchRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :research_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.string :scope, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :claimed_at
      t.string :client_id
      t.string :error
      t.timestamps

      t.index :status, unique: true, where: "status = 'pending'", name: "index_research_requests_one_pending"
      t.check_constraint "scope IN ('soon', 'all')", name: "research_requests_scope"
      t.check_constraint "status IN ('pending', 'claimed', 'cancelled', 'expired', 'failed')", name: "research_requests_status"
    end
  end
end
