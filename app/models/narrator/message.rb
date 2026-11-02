class Narrator::Message < ApplicationRecord
  acts_as_message chat: :conversation, chat_class: "Narrator::Conversation"
end
