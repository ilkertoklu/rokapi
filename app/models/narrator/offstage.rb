class Narrator::Offstage < RubyLLM::Agent
  MODEL = "gpt-5.6"

  model MODEL
  inputs :game_session

  attr_reader :game_session

  def self.for(game_session)
    if game_session.persisted?
      new game_session: game_session, chat: game_session.conversations.planning.create!(model: MODEL)
    else
      new game_session: game_session
    end
  end

  def initialize(game_session:, **)
    @game_session = game_session
    super
  end
end
