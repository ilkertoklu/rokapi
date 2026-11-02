class Narrator::Voice < RubyLLM::Agent
  chat_model Chat
  caching
  instructions brief: -> { Narrator::Brief.new(chat.game_session) }
end
