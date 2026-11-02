class Narrator::Voice < RubyLLM::Agent
  chat_model Narrator::Conversation
  caching
  instructions game: -> { chat.game_session }
end
