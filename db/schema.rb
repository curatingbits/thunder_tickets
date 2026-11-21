# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_21_150000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.string "name", null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.string "scopes", default: "", null: false
    t.datetime "last_used_at"
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.integer "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_api_tokens_on_created_by_id"
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
  end

  create_table "app_settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.integer "updated_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_app_settings_on_key", unique: true
    t.index ["updated_by_id"], name: "index_app_settings_on_updated_by_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "auditable_type", null: false
    t.integer "auditable_id", null: false
    t.string "action", null: false
    t.json "changeset", default: {}, null: false
    t.text "note"
    t.integer "user_id"
    t.integer "api_token_id"
    t.datetime "created_at", null: false
    t.index ["api_token_id"], name: "index_audit_events_on_api_token_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "buyers", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_buyers_on_email"
    t.index ["name"], name: "index_buyers_on_name"
  end

  create_table "games", force: :cascade do |t|
    t.integer "season_id", null: false
    t.integer "game_number"
    t.date "game_date"
    t.integer "opponent_id", null: false
    t.decimal "cost_per_ticket"
    t.decimal "parking_cost"
    t.string "game_type"
    t.string "playoff_round"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "tipoff_at"
    t.string "ticketmaster_event_id"
    t.string "ticketmaster_url"
    t.integer "series_game_number"
    t.index ["opponent_id"], name: "index_games_on_opponent_id"
    t.index ["season_id"], name: "index_games_on_season_id"
    t.index ["ticketmaster_event_id"], name: "index_games_on_ticketmaster_event_id", unique: true, where: "ticketmaster_event_id IS NOT NULL"
  end

  create_table "import_runs", force: :cascade do |t|
    t.string "kind", null: false
    t.string "source", null: false
    t.string "key", null: false
    t.string "status", default: "running", null: false
    t.string "lease_owner"
    t.datetime "last_activity_at"
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.json "params", default: {}, null: false
    t.json "stats", default: {}, null: false
    t.json "error_log", default: [], null: false
    t.text "notes"
    t.string "agent_version"
    t.integer "api_token_id"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token_id"], name: "index_import_runs_on_api_token_id"
    t.index ["key"], name: "index_import_runs_on_key", unique: true
    t.index ["kind"], name: "index_import_runs_one_running_per_kind", unique: true, where: "status = 'running'"
    t.index ["user_id"], name: "index_import_runs_on_user_id"
    t.check_constraint "kind IN ('market_research', 'payment_sync')", name: "import_runs_kind"
    t.check_constraint "status IN ('running', 'completed', 'partial', 'blocked', 'failed', 'abandoned')", name: "import_runs_status"
  end

  create_table "listing_events", force: :cascade do |t|
    t.integer "game_id", null: false
    t.integer "listing_id"
    t.string "action", null: false
    t.decimal "price_before", precision: 10, scale: 2
    t.decimal "price_after", precision: 10, scale: 2
    t.string "recommended_strategy"
    t.decimal "recommended_list_price", precision: 10, scale: 2
    t.text "note"
    t.integer "user_id"
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.integer "market_snapshot_id"
    t.index ["game_id", "occurred_at"], name: "index_listing_events_on_game_id_and_occurred_at"
    t.index ["game_id"], name: "index_listing_events_on_game_id"
    t.index ["listing_id"], name: "index_listing_events_on_listing_id"
    t.index ["market_snapshot_id"], name: "index_listing_events_on_market_snapshot_id"
    t.index ["user_id"], name: "index_listing_events_on_user_id"
    t.check_constraint "action IN ('listed', 'price_changed', 'verified', 'verified_unlisted', 'held', 'ended')", name: "listing_events_action"
  end

  create_table "listings", force: :cascade do |t|
    t.integer "game_id", null: false
    t.string "kind", default: "listing", null: false
    t.json "seat_numbers", default: [], null: false
    t.string "platform"
    t.integer "account_user_id"
    t.decimal "ask_price", precision: 10, scale: 2
    t.string "ask_price_basis", default: "seller_list", null: false
    t.string "status", default: "active", null: false
    t.string "end_reason"
    t.datetime "verified_at"
    t.integer "verified_by_id"
    t.datetime "ended_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_user_id"], name: "index_listings_on_account_user_id"
    t.index ["game_id", "status"], name: "index_listings_on_game_id_and_status"
    t.index ["game_id"], name: "index_listings_on_game_id"
    t.index ["verified_by_id"], name: "index_listings_on_verified_by_id"
    t.check_constraint "ask_price IS NULL OR ask_price > 0", name: "listings_ask_price_positive"
    t.check_constraint "ask_price_basis IN ('seller_list', 'buyer_all_in')", name: "listings_ask_price_basis"
    t.check_constraint "kind IN ('listing', 'hold')", name: "listings_kind"
    t.check_constraint "status IN ('active', 'ended')", name: "listings_status"
  end

  create_table "market_observations", force: :cascade do |t|
    t.integer "market_snapshot_id", null: false
    t.integer "position", null: false
    t.string "section", null: false
    t.string "row"
    t.integer "row_rank"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.string "ticket_type", default: "verified_resale", null: false
    t.integer "tier"
    t.decimal "weight", precision: 6, scale: 4, default: "0.0", null: false
    t.decimal "dd_equivalent_price", precision: 10, scale: 2
    t.string "excluded_reason"
    t.string "raw_label"
    t.datetime "created_at", null: false
    t.json "seats"
    t.index ["market_snapshot_id", "position"], name: "index_market_observations_on_market_snapshot_id_and_position", unique: true
    t.index ["market_snapshot_id"], name: "index_market_observations_on_market_snapshot_id"
  end

  create_table "market_snapshots", force: :cascade do |t|
    t.integer "import_run_id", null: false
    t.integer "game_id", null: false
    t.datetime "captured_at", null: false
    t.integer "days_to_game", null: false
    t.string "event_id"
    t.string "event_url"
    t.string "event_title"
    t.integer "quantity_filter", default: 2, null: false
    t.string "price_basis", default: "all_in_ex_tax", null: false
    t.integer "event_total_listings"
    t.integer "captured_count", default: 0, null: false
    t.boolean "scroll_complete", default: true, null: false
    t.string "payload_digest", null: false
    t.string "engine_version", null: false
    t.json "settings_used", default: {}, null: false
    t.integer "tier1_count", default: 0, null: false
    t.integer "tier2_count", default: 0, null: false
    t.integer "tier3_count", default: 0, null: false
    t.integer "section_count", default: 0, null: false
    t.integer "excluded_count", default: 0, null: false
    t.decimal "comp_weight", precision: 8, scale: 3, default: "0.0", null: false
    t.decimal "comp_min", precision: 10, scale: 2
    t.decimal "comp_p25", precision: 10, scale: 2
    t.decimal "comp_median", precision: 10, scale: 2
    t.decimal "comp_mean", precision: 10, scale: 2
    t.decimal "comp_p75", precision: 10, scale: 2
    t.decimal "comp_max", precision: 10, scale: 2
    t.decimal "section_min", precision: 10, scale: 2
    t.decimal "section_median", precision: 10, scale: 2
    t.decimal "section_max", precision: 10, scale: 2
    t.decimal "near_raw_median", precision: 10, scale: 2
    t.decimal "row_premium", precision: 6, scale: 3
    t.string "row_premium_source"
    t.decimal "primary_min_price", precision: 10, scale: 2
    t.json "distribution", default: {}, null: false
    t.decimal "buyer_fee_multiplier", precision: 6, scale: 4, null: false
    t.decimal "fee_evidence_share", precision: 5, scale: 3
    t.boolean "fee_verified", default: false, null: false
    t.decimal "competitive_price", precision: 10, scale: 2
    t.decimal "market_value", precision: 10, scale: 2
    t.decimal "premium_price", precision: 10, scale: 2
    t.string "recommended_strategy"
    t.decimal "recommended_list_price", precision: 10, scale: 2
    t.json "rationale", default: [], null: false
    t.integer "confidence", default: 0, null: false
    t.json "confidence_breakdown", default: {}, null: false
    t.decimal "our_ask_price", precision: 10, scale: 2
    t.string "our_ask_basis"
    t.decimal "our_all_in", precision: 10, scale: 2
    t.string "assessment"
    t.boolean "observed_our_listing", default: false, null: false
    t.integer "previous_snapshot_id"
    t.decimal "market_value_change_pct", precision: 7, scale: 2
    t.integer "section_count_change"
    t.datetime "invalidated_at"
    t.string "invalidation_reason"
    t.datetime "created_at", null: false
    t.index ["game_id", "captured_at"], name: "index_market_snapshots_on_game_id_and_captured_at"
    t.index ["game_id"], name: "index_market_snapshots_on_game_id"
    t.index ["import_run_id", "game_id"], name: "index_market_snapshots_on_import_run_id_and_game_id", unique: true
    t.index ["import_run_id"], name: "index_market_snapshots_on_import_run_id"
    t.index ["previous_snapshot_id"], name: "index_market_snapshots_on_previous_snapshot_id"
  end

  create_table "partner_payments", force: :cascade do |t|
    t.integer "import_run_id"
    t.string "source", null: false
    t.string "external_id", null: false
    t.date "occurred_on", null: false
    t.integer "amount_cents", null: false
    t.string "direction", null: false
    t.string "counterparty"
    t.text "memo"
    t.string "raw_name"
    t.string "account_name"
    t.string "category", default: "unknown", null: false
    t.string "status", default: "unmatched", null: false
    t.integer "match_confidence"
    t.json "match_details", default: {}, null: false
    t.integer "possible_duplicate_of_id"
    t.datetime "source_missing_at"
    t.integer "reviewed_by_id"
    t.datetime "reviewed_at"
    t.text "review_note"
    t.json "raw", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["import_run_id"], name: "index_partner_payments_on_import_run_id"
    t.index ["occurred_on", "amount_cents", "direction"], name: "idx_on_occurred_on_amount_cents_direction_3b9cebf88d"
    t.index ["possible_duplicate_of_id"], name: "index_partner_payments_on_possible_duplicate_of_id"
    t.index ["reviewed_by_id"], name: "index_partner_payments_on_reviewed_by_id"
    t.index ["source", "external_id"], name: "index_partner_payments_on_source_and_external_id", unique: true
    t.index ["status", "occurred_on"], name: "index_partner_payments_on_status_and_occurred_on"
    t.check_constraint "amount_cents > 0", name: "partner_payments_amount_positive"
    t.check_constraint "category IN ('settlement', 'cost_share', 'unrelated', 'unknown')", name: "partner_payments_category"
    t.check_constraint "direction IN ('incoming', 'outgoing')", name: "partner_payments_direction"
    t.check_constraint "status IN ('unmatched', 'partially_matched', 'matched', 'needs_review', 'ignored')", name: "partner_payments_status"
  end

  create_table "research_requests", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "scope", null: false
    t.string "status", default: "pending", null: false
    t.datetime "claimed_at"
    t.string "client_id"
    t.string "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_research_requests_one_pending", unique: true, where: "status = 'pending'"
    t.index ["user_id"], name: "index_research_requests_on_user_id"
    t.check_constraint "scope IN ('soon', 'all')", name: "research_requests_scope"
    t.check_constraint "status IN ('pending', 'claimed', 'cancelled', 'expired', 'failed')", name: "research_requests_status"
  end

  create_table "seasons", force: :cascade do |t|
    t.string "year"
    t.decimal "total_season_cost"
    t.boolean "is_current"
    t.integer "num_seats"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seat_section"
    t.string "seat_row", default: "DD"
    t.boolean "settlement_tracked", default: true, null: false
    t.decimal "partner_split_pct", precision: 5, scale: 2, default: "50.0", null: false
    t.index ["year"], name: "index_seasons_on_year", unique: true
  end

  create_table "settlement_allocations", force: :cascade do |t|
    t.integer "partner_payment_id", null: false
    t.integer "game_id", null: false
    t.integer "amount_cents", null: false
    t.string "method", null: false
    t.integer "confidence"
    t.string "reason", null: false
    t.integer "created_by_id"
    t.datetime "voided_at"
    t.integer "voided_by_id"
    t.string "void_reason"
    t.integer "replaces_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_settlement_allocations_on_created_by_id"
    t.index ["game_id"], name: "index_settlement_allocations_on_game_id"
    t.index ["partner_payment_id", "game_id"], name: "index_settlement_allocations_one_active_per_payment_game", unique: true, where: "voided_at IS NULL"
    t.index ["partner_payment_id"], name: "index_settlement_allocations_on_partner_payment_id"
    t.index ["replaces_id"], name: "index_settlement_allocations_on_replaces_id"
    t.index ["voided_by_id"], name: "index_settlement_allocations_on_voided_by_id"
    t.check_constraint "amount_cents <> 0", name: "settlement_allocations_amount_nonzero"
    t.check_constraint "method IN ('auto', 'manual')", name: "settlement_allocations_method"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name"
    t.string "abbreviation"
    t.string "conference"
    t.string "division"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tickets", force: :cascade do |t|
    t.integer "game_id", null: false
    t.integer "seat_number"
    t.decimal "sale_price"
    t.datetime "sold_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "section"
    t.string "row"
    t.integer "buyer_id"
    t.datetime "transferred_at"
    t.integer "listing_id"
    t.decimal "list_price_at_sale", precision: 10, scale: 2
    t.string "payout_received_by", default: "partner", null: false
    t.index ["buyer_id"], name: "index_tickets_on_buyer_id"
    t.index ["game_id"], name: "index_tickets_on_game_id"
    t.index ["listing_id"], name: "index_tickets_on_listing_id"
    t.check_constraint "payout_received_by IN ('partner', 'owner')", name: "tickets_payout_received_by"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.string "name"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.string "invited_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true, null: false
    t.string "invitation_token"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.index ["active"], name: "index_users_on_active"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "users", column: "created_by_id"
  add_foreign_key "app_settings", "users", column: "updated_by_id"
  add_foreign_key "audit_events", "api_tokens"
  add_foreign_key "audit_events", "users"
  add_foreign_key "games", "seasons"
  add_foreign_key "games", "teams", column: "opponent_id"
  add_foreign_key "import_runs", "api_tokens"
  add_foreign_key "import_runs", "users"
  add_foreign_key "listing_events", "games"
  add_foreign_key "listing_events", "listings"
  add_foreign_key "listing_events", "market_snapshots"
  add_foreign_key "listing_events", "users"
  add_foreign_key "listings", "games"
  add_foreign_key "listings", "users", column: "account_user_id"
  add_foreign_key "listings", "users", column: "verified_by_id"
  add_foreign_key "market_observations", "market_snapshots"
  add_foreign_key "market_snapshots", "games"
  add_foreign_key "market_snapshots", "import_runs"
  add_foreign_key "market_snapshots", "market_snapshots", column: "previous_snapshot_id"
  add_foreign_key "partner_payments", "import_runs"
  add_foreign_key "partner_payments", "partner_payments", column: "possible_duplicate_of_id"
  add_foreign_key "partner_payments", "users", column: "reviewed_by_id"
  add_foreign_key "research_requests", "users"
  add_foreign_key "settlement_allocations", "games"
  add_foreign_key "settlement_allocations", "partner_payments"
  add_foreign_key "settlement_allocations", "settlement_allocations", column: "replaces_id"
  add_foreign_key "settlement_allocations", "users", column: "created_by_id"
  add_foreign_key "settlement_allocations", "users", column: "voided_by_id"
  add_foreign_key "tickets", "buyers"
  add_foreign_key "tickets", "games"
  add_foreign_key "tickets", "listings"
end
