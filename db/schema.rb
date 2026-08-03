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

ActiveRecord::Schema[8.1].define(version: 2026_08_03_221456) do
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

  create_table "choices", force: :cascade do |t|
    t.datetime "chosen_at"
    t.datetime "created_at", null: false
    t.integer "difficulty", null: false
    t.string "difficulty_label", null: false
    t.string "difficulty_reason"
    t.string "label", null: false
    t.integer "modifier", default: 0, null: false
    t.integer "scene_id", null: false
    t.string "stat", null: false
    t.datetime "updated_at", null: false
    t.index ["scene_id"], name: "index_choices_on_chosen_scene", unique: true, where: "chosen_at IS NOT NULL"
    t.index ["scene_id"], name: "index_choices_on_scene_id"
  end

  create_table "game_sessions", force: :cascade do |t|
    t.integer "adventure_id"
    t.text "context_summary"
    t.integer "context_summary_position", default: 0, null: false
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

  create_table "llm_calls", force: :cascade do |t|
    t.integer "cost_in_microdollars", null: false
    t.datetime "created_at", null: false
    t.integer "game_session_id", null: false
    t.integer "input_tokens", null: false
    t.string "model", null: false
    t.integer "output_tokens", null: false
    t.string "purpose", null: false
    t.datetime "updated_at", null: false
    t.index ["game_session_id"], name: "index_llm_calls_on_game_session_id"
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

  create_table "rolls", force: :cascade do |t|
    t.datetime "acknowledged_at"
    t.integer "choice_id", null: false
    t.datetime "created_at", null: false
    t.json "effects"
    t.datetime "failed_at"
    t.integer "modifier", null: false
    t.integer "player_id", null: false
    t.text "resolution"
    t.boolean "success", null: false
    t.integer "target", null: false
    t.datetime "updated_at", null: false
    t.integer "value", null: false
    t.index ["choice_id"], name: "index_rolls_on_choice_id", unique: true
    t.index ["player_id"], name: "index_rolls_on_player_id"
  end

  create_table "scenes", force: :cascade do |t|
    t.integer "active_player_id", null: false
    t.datetime "created_at", null: false
    t.boolean "finale", default: false, null: false
    t.integer "game_session_id", null: false
    t.string "location"
    t.text "narration"
    t.integer "position", null: false
    t.string "state", default: "narrating", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["active_player_id"], name: "index_scenes_on_active_player_id"
    t.index ["game_session_id", "position"], name: "index_scenes_on_game_session_id_and_position", unique: true
    t.index ["game_session_id"], name: "index_scenes_on_game_session_id"
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
  add_foreign_key "choices", "scenes"
  add_foreign_key "game_sessions", "adventures"
  add_foreign_key "game_sessions", "users", column: "creator_id"
  add_foreign_key "llm_calls", "game_sessions"
  add_foreign_key "login_codes", "users"
  add_foreign_key "players", "game_sessions"
  add_foreign_key "players", "users"
  add_foreign_key "rolls", "choices"
  add_foreign_key "rolls", "players"
  add_foreign_key "scenes", "game_sessions"
  add_foreign_key "scenes", "players", column: "active_player_id"
  add_foreign_key "sessions", "users"
end
