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

ActiveRecord::Schema[8.0].define(version: 2025_10_25_003323) do
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

  create_table "seasons", force: :cascade do |t|
    t.string "year"
    t.decimal "total_season_cost"
    t.boolean "is_current"
    t.integer "num_seats"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.string "buyer_name"
    t.string "buyer_email"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "games", "seasons"
  add_foreign_key "games", "teams", column: "opponent_id"
  add_foreign_key "tickets", "games"
end
