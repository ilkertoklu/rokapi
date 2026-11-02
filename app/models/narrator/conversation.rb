class Narrator::Conversation < ApplicationRecord
  acts_as_chat message_class: "Narrator::Message", messages_foreign_key: :conversation_id

  belongs_to :game_session

  def forget_last_exchange
    messages.reload.last(2).each(&:destroy)
  end

  def settle(cue)
    messages.reload.where(role: "user").last.update! content: cue
  end
end
