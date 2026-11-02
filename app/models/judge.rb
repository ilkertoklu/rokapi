class Judge < RubyLLM::Agent
  MODEL = "claude-opus-5-5"

  model MODEL, provider: :anthropic, assume_model_exists: true
  schema Judge::VerdictSchema

  def initialize
    super(chat: understudy)
  end

  private
    def understudy
      command = Rails.configuration.x.narrator_command.presence
      Narrator::Understudy.new(command).with_model(MODEL) if command
    end
end
