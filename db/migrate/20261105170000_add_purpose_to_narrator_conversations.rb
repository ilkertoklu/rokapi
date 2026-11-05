class AddPurposeToNarratorConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :narrator_conversations, :purpose, :string, null: false, default: "narration"

    remove_index :narrator_conversations, :game_session_id, unique: true
    add_index :narrator_conversations, :game_session_id
    add_index :narrator_conversations, :game_session_id, unique: true, where: "purpose = 'narration'", name: "index_narrator_conversations_on_game_session_id_narration"
  end
end
