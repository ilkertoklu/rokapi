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

ActiveRecord::Schema[8.1].define(version: 2026_07_30_100004) do
  create_table "adventures", force: :cascade do |t|
    t.text "brief", null: false
    t.datetime "created_at", null: false
    t.string "hook", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_adventures_on_title", unique: true
  end

  create_table "characters", force: :cascade do |t|
    t.string "background", null: false
    t.datetime "created_at", null: false
    t.integer "hp", null: false
    t.string "klass", null: false
    t.integer "max_hp", null: false
    t.integer "player_id", null: false
    t.string "race", null: false
    t.json "stats", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_characters_on_player_id", unique: true
  end

  create_table "game_sessions", force: :cascade do |t|
    t.integer "adventure_id"
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.datetime "ended_at"
    t.string "length", null: false
    t.string "mode", null: false
    t.string "outcome"
    t.string "room_code"
    t.string "state", default: "lobby", null: false
    t.string "tone", null: false
    t.datetime "updated_at", null: false
    t.index ["adventure_id"], name: "index_game_sessions_on_adventure_id"
    t.index ["creator_id"], name: "index_game_sessions_on_creator_id"
    t.index ["room_code"], name: "index_game_sessions_on_room_code", unique: true, where: "state = 'lobby' AND room_code IS NOT NULL"
  end

  create_table "login_codes", force: :cascade do |t|
    t.integer "attempts_count", default: 0, null: false
    t.string "code_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_login_codes_on_user_id"
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "game_session_id", null: false
    t.boolean "host", default: false, null: false
    t.boolean "ready", default: false, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["game_session_id", "user_id"], name: "index_players_on_game_session_id_and_user_id", unique: true
    t.index ["game_session_id"], name: "index_players_on_game_session_id"
    t.index ["user_id"], name: "index_players_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "last_active_at", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.datetime "terms_accepted_at"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "characters", "players"
  add_foreign_key "game_sessions", "adventures"
  add_foreign_key "game_sessions", "users", column: "creator_id"
  add_foreign_key "login_codes", "users"
  add_foreign_key "players", "game_sessions"
  add_foreign_key "players", "users"
  add_foreign_key "sessions", "users"
end
