class Narrator::Voice < RubyLLM::Agent
  chat_model Narrator::Conversation
  caching
  instructions brief: -> { Narrator::Brief.new(chat.game_session) }
end
