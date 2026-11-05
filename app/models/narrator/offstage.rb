class Narrator::Offstage < RubyLLM::Agent
  model "claude-opus-5-5"
  inputs :game_session

  attr_reader :game_session

  def self.for(game_session)
    if Rails.configuration.x.narrator_command.present?
      new game_session: game_session, provider: :understudy, assume_model_exists: true
    else
      new game_session: game_session
    end
  end

  def initialize(game_session:, **)
    @game_session = game_session
    super
  end
end
