# One automated or manual data run (Ticketmaster research, Venmo sync): its
# idempotency key, a lease so two clients can't run at once, and a log.
class CreateImportRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :import_runs do |t|
      t.string :kind, null: false
      t.string :source, null: false
      t.string :key, null: false
      t.string :status, null: false, default: "running"
      t.string :lease_owner
      t.datetime :last_activity_at
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.json :params, null: false, default: {}
      t.json :stats, null: false, default: {}
      t.json :error_log, null: false, default: []
      t.text :notes
      t.string :agent_version
      t.references :api_token, foreign_key: true
      t.references :user, foreign_key: true
      t.timestamps

      t.index :key, unique: true
      # At most one run of each kind in progress.
      t.index :kind, unique: true, where: "status = 'running'", name: "index_import_runs_one_running_per_kind"
      t.check_constraint "kind IN ('market_research', 'payment_sync')", name: "import_runs_kind"
      t.check_constraint "status IN ('running', 'completed', 'partial', 'blocked', 'failed', 'abandoned')", name: "import_runs_status"
    end
  end
end
