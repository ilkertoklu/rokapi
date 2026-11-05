class Narrator::Offstage < RubyLLM::Agent
  MODEL = "claude-opus-5-5"

  model MODEL
  inputs :game_session

  attr_reader :game_session

  def self.for(game_session)
    understudy = Rails.configuration.x.narrator_command.present? ? { provider: :understudy, assume_model_exists: true } : {}

    if game_session.persisted?
      new game_session: game_session, chat: game_session.conversations.planning.create!(model: MODEL, **understudy)
    else
      new game_session: game_session, **understudy
    end
  end

  def initialize(game_session:, **)
    @game_session = game_session
    super
  end
end
