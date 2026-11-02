class NameTheNarratorConversation < ActiveRecord::Migration[8.1]
  def change
    rename_table :chats, :narrator_conversations
    rename_table :messages, :narrator_messages
    rename_column :narrator_messages, :chat_id, :conversation_id

    reversible do |direction|
      direction.up { retype from: { "Chat" => "Narrator::Conversation", "Message" => "Narrator::Message" } }
      direction.down { retype from: { "Narrator::Conversation" => "Chat", "Narrator::Message" => "Message" } }
    end
  end

  private
    def retype(from:)
      from.each do |old, new|
        execute "UPDATE ruby_llm_usages SET chat_type = '#{new}' WHERE chat_type = '#{old}'"
        execute "UPDATE ruby_llm_usages SET message_type = '#{new}' WHERE message_type = '#{old}'"
        execute "UPDATE ruby_llm_tool_calls SET message_type = '#{new}' WHERE message_type = '#{old}'"
      end
    end
end
