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

ActiveRecord::Schema[8.0].define(version: 2025_12_08_163308) do
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
    t.index ["opponent_id"], name: "index_games_on_opponent_id"
    t.index ["season_id"], name: "index_games_on_season_id"
  end

  create_table "market_prices", force: :cascade do |t|
    t.integer "game_id", null: false
    t.string "section"
    t.decimal "min_price", precision: 10, scale: 2
    t.decimal "max_price", precision: 10, scale: 2
    t.decimal "average_price", precision: 10, scale: 2
    t.integer "listings_count"
    t.datetime "fetched_at"
    t.string "event_id"
    t.string "event_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_market_prices_on_event_id"
    t.index ["fetched_at"], name: "index_market_prices_on_fetched_at"
    t.index ["game_id"], name: "index_market_prices_on_game_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.string "year"
    t.decimal "total_season_cost"
    t.boolean "is_current"
    t.integer "num_seats"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seat_section"
    t.index ["year"], name: "index_seasons_on_year", unique: true
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
    t.index ["buyer_id"], name: "index_tickets_on_buyer_id"
    t.index ["game_id"], name: "index_tickets_on_game_id"
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
  add_foreign_key "games", "seasons"
  add_foreign_key "games", "teams", column: "opponent_id"
  add_foreign_key "market_prices", "games"
  add_foreign_key "tickets", "buyers"
  add_foreign_key "tickets", "games"
end
