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

ActiveRecord::Schema[8.1].define(version: 2026_11_02_200000) do
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
    t.string "difficulty_reason"
    t.string "label", null: false
    t.integer "modifier", default: 0, null: false
    t.integer "scene_id", null: false
    t.string "stat", null: false
    t.integer "target", null: false
    t.datetime "updated_at", null: false
    t.index ["scene_id"], name: "index_choices_on_chosen_scene", unique: true, where: "chosen_at IS NOT NULL"
    t.index ["scene_id"], name: "index_choices_on_scene_id"
  end

  create_table "game_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.datetime "ended_at"
    t.string "length", null: false
    t.string "locale", default: "en", null: false
    t.string "outcome"
    t.string "quest"
    t.datetime "started_at"
    t.string "tone", null: false
    t.datetime "updated_at", null: false
    t.string "code"
    t.integer "max_players", default: 1, null: false
    t.integer "rematch_of_id"
    t.string "title"
    t.index ["code"], name: "index_game_sessions_on_code", unique: true, where: "started_at IS NULL"
    t.index ["creator_id"], name: "index_game_sessions_on_creator_id"
    t.index ["rematch_of_id"], name: "index_game_sessions_on_rematch_of_id", unique: true
  end

  create_table "items", force: :cascade do |t|
    t.integer "character_id", null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.integer "hp_effect", default: 0, null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.integer "uses_left"
    t.index ["character_id"], name: "index_items_on_character_id"
  end

  create_table "login_codes", force: :cascade do |t|
    t.integer "attempts_count", default: 0, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_login_codes_on_user_id"
  end

  create_table "narrator_conversations", force: :cascade do |t|
    t.integer "game_session_id", null: false
    t.bigint "ruby_llm_model_id", null: false
    t.boolean "cancelled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_session_id"], name: "index_narrator_conversations_on_game_session_id", unique: true
    t.index ["ruby_llm_model_id"], name: "index_narrator_conversations_on_ruby_llm_model_id"
  end

  create_table "narrator_messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "role", null: false
    t.text "content"
    t.boolean "cache_until_here", default: false, null: false
    t.text "thinking_text"
    t.text "thinking_signature"
    t.json "citations"
    t.json "server_tool_calls"
    t.json "raw_content"
    t.json "raw_reasoning"
    t.string "finish_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_narrator_messages_on_conversation_id"
  end

  create_table "pay_charges", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "subscription_id"
    t.string "processor_id", null: false
    t.integer "amount", null: false
    t.string "currency"
    t.integer "application_fee_amount"
    t.integer "amount_refunded"
    t.json "metadata"
    t.json "data"
    t.string "stripe_account"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.json "object"
    t.index ["customer_id", "processor_id"], name: "index_pay_charges_on_customer_id_and_processor_id", unique: true
    t.index ["subscription_id"], name: "index_pay_charges_on_subscription_id"
  end

  create_table "pay_customers", force: :cascade do |t|
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "processor", null: false
    t.string "processor_id"
    t.boolean "default"
    t.json "data"
    t.string "stripe_account"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.json "object"
    t.index ["owner_type", "owner_id", "deleted_at"], name: "pay_customer_owner_index", unique: true
    t.index ["processor", "processor_id"], name: "index_pay_customers_on_processor_and_processor_id", unique: true
  end

  create_table "pay_merchants", force: :cascade do |t|
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "processor", null: false
    t.string "processor_id"
    t.boolean "default"
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.index ["owner_type", "owner_id", "processor"], name: "index_pay_merchants_on_owner_type_and_owner_id_and_processor"
  end

  create_table "pay_payment_methods", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "processor_id", null: false
    t.boolean "default"
    t.string "payment_method_type"
    t.json "data"
    t.string "stripe_account"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.index ["customer_id", "processor_id"], name: "index_pay_payment_methods_on_customer_id_and_processor_id", unique: true
  end

  create_table "pay_subscriptions", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "name", null: false
    t.string "processor_id", null: false
    t.string "processor_plan", null: false
    t.integer "quantity", default: 1, null: false
    t.string "status", null: false
    t.datetime "current_period_start", precision: nil
    t.datetime "current_period_end", precision: nil
    t.datetime "trial_ends_at", precision: nil
    t.datetime "ends_at", precision: nil
    t.boolean "metered"
    t.string "pause_behavior"
    t.datetime "pause_starts_at", precision: nil
    t.datetime "pause_resumes_at", precision: nil
    t.decimal "application_fee_percent", precision: 8, scale: 2
    t.json "metadata"
    t.json "data"
    t.string "stripe_account"
    t.string "payment_method_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.json "object"
    t.index ["customer_id", "processor_id"], name: "index_pay_subscriptions_on_customer_id_and_processor_id", unique: true
    t.index ["metered"], name: "index_pay_subscriptions_on_metered"
    t.index ["pause_starts_at"], name: "index_pay_subscriptions_on_pause_starts_at"
  end

  create_table "pay_webhooks", force: :cascade do |t|
    t.string "processor"
    t.string "event_type"
    t.json "event"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "game_session_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["game_session_id", "user_id"], name: "index_players_on_game_session_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_players_on_user_id"
  end

  create_table "rolls", force: :cascade do |t|
    t.datetime "acknowledged_at"
    t.integer "choice_id", null: false
    t.datetime "created_at", null: false
    t.json "effects"
    t.integer "player_id", null: false
    t.text "resolution"
    t.datetime "stalled_at"
    t.integer "status_modifier", default: 0, null: false
    t.boolean "success", null: false
    t.datetime "updated_at", null: false
    t.integer "value", null: false
    t.index ["choice_id"], name: "index_rolls_on_choice_id", unique: true
    t.index ["player_id"], name: "index_rolls_on_player_id"
  end

  create_table "ruby_llm_batches", force: :cascade do |t|
    t.string "provider_batch_id", null: false
    t.string "provider", null: false
    t.string "status", null: false
    t.string "raw_status"
    t.boolean "completed", default: false, null: false
    t.string "chat_type"
    t.string "batch_protocol"
    t.json "chat_ids", default: []
    t.json "request_counts"
    t.json "reported_cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_batch_id"], name: "index_ruby_llm_batches_on_provider_and_provider_batch_id", unique: true
    t.index ["status"], name: "index_ruby_llm_batches_on_status"
  end

  create_table "ruby_llm_models", force: :cascade do |t|
    t.string "model_id", null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.string "family"
    t.datetime "model_created_at"
    t.integer "context_window"
    t.integer "max_output_tokens"
    t.date "knowledge_cutoff"
    t.datetime "unlisted_at"
    t.json "modalities", default: {}
    t.json "capabilities", default: []
    t.json "pricing", default: {}
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family"], name: "index_ruby_llm_models_on_family"
    t.index ["provider", "model_id"], name: "index_ruby_llm_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_ruby_llm_models_on_provider"
  end

  create_table "ruby_llm_tool_calls", force: :cascade do |t|
    t.string "message_type", null: false
    t.bigint "message_id", null: false
    t.string "result_type"
    t.bigint "result_id"
    t.string "tool_call_id", null: false
    t.string "name", null: false
    t.text "thought_signature"
    t.string "approval"
    t.boolean "remote", default: false, null: false
    t.json "arguments", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_type", "message_id"], name: "index_ruby_llm_tool_calls_on_message_type_and_message_id"
    t.index ["name"], name: "index_ruby_llm_tool_calls_on_name"
    t.index ["result_type", "result_id"], name: "index_ruby_llm_tool_calls_on_result_type_and_result_id"
    t.index ["tool_call_id"], name: "index_ruby_llm_tool_calls_on_tool_call_id", unique: true
  end

  create_table "ruby_llm_usages", force: :cascade do |t|
    t.string "chat_type", null: false
    t.bigint "chat_id", null: false
    t.string "message_type"
    t.bigint "message_id"
    t.string "operation", null: false
    t.string "provider", null: false
    t.string "model", null: false
    t.string "status", null: false
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.integer "cache_read_tokens"
    t.integer "cache_write_tokens"
    t.integer "thinking_tokens"
    t.decimal "input_cost", precision: 16, scale: 10
    t.decimal "output_cost", precision: 16, scale: 10
    t.decimal "cache_read_cost", precision: 16, scale: 10
    t.decimal "cache_write_cost", precision: 16, scale: 10
    t.decimal "thinking_cost", precision: 16, scale: 10
    t.decimal "total_cost", precision: 16, scale: 10
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_type", "chat_id"], name: "index_ruby_llm_usages_on_chat_type_and_chat_id"
    t.index ["message_type", "message_id"], name: "index_ruby_llm_usages_on_message_type_and_message_id"
    t.index ["status"], name: "index_ruby_llm_usages_on_status"
    t.check_constraint "operation IN ('chat', 'embedding', 'moderation', 'image', 'speech', 'transcription', 'ocr', 'rerank')"
    t.check_constraint "status IN ('pending', 'succeeded', 'failed', 'cancelled')"
  end

  create_table "scenes", force: :cascade do |t|
    t.integer "active_player_id", null: false
    t.datetime "created_at", null: false
    t.boolean "finale", default: false, null: false
    t.integer "game_session_id", null: false
    t.string "location"
    t.text "narration"
    t.integer "position", null: false
    t.datetime "stalled_at"
    t.string "state", default: "narrating", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["active_player_id"], name: "index_scenes_on_active_player_id"
    t.index ["game_session_id", "position"], name: "index_scenes_on_game_session_id_and_position", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "status_effects", force: :cascade do |t|
    t.integer "character_id", null: false
    t.datetime "created_at", null: false
    t.string "expires_when"
    t.integer "modifier", null: false
    t.string "name", null: false
    t.integer "turns_left"
    t.datetime "updated_at", null: false
    t.index ["character_id", "name"], name: "index_status_effects_on_character_id_and_name", unique: true
    t.check_constraint "modifier BETWEEN -2 AND 2", name: "status_effects_modifier_within_dice_range"
    t.check_constraint "turns_left IS NOT NULL OR expires_when IS NOT NULL", name: "status_effects_have_a_duration"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.datetime "terms_accepted_at"
    t.datetime "updated_at", null: false
    t.string "unconfirmed_email"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "characters", "players"
  add_foreign_key "choices", "scenes"
  add_foreign_key "game_sessions", "game_sessions", column: "rematch_of_id", on_delete: :nullify
  add_foreign_key "game_sessions", "users", column: "creator_id"
  add_foreign_key "items", "characters"
  add_foreign_key "login_codes", "users"
  add_foreign_key "narrator_conversations", "game_sessions"
  add_foreign_key "narrator_conversations", "ruby_llm_models"
  add_foreign_key "narrator_messages", "narrator_conversations", column: "conversation_id"
  add_foreign_key "pay_charges", "pay_customers", column: "customer_id"
  add_foreign_key "pay_charges", "pay_subscriptions", column: "subscription_id"
  add_foreign_key "pay_payment_methods", "pay_customers", column: "customer_id"
  add_foreign_key "pay_subscriptions", "pay_customers", column: "customer_id"
  add_foreign_key "players", "game_sessions"
  add_foreign_key "players", "users"
  add_foreign_key "rolls", "choices"
  add_foreign_key "rolls", "players"
  add_foreign_key "scenes", "game_sessions"
  add_foreign_key "scenes", "players", column: "active_player_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "status_effects", "characters"
end
