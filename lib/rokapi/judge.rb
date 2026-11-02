module Rokapi
  class Judge < RubyLLM::Agent
    MODEL = "claude-opus-5-5"

    class VerdictSchema < Schematist::Schema
      string :better, enum: %w[first second], description: "The playthrough that was the better story to have played"
      string :confidence, enum: %w[low medium high], description: "How sure you are"
      string :reason, description: "Why, in a few sentences"
      string :improvement, description: "The single change that would most improve the other playthrough"
    end

    model MODEL, provider: :anthropic, assume_model_exists: true
    schema VerdictSchema
    instructions <<~TEXT
      You are a seasoned editor of interactive fiction and game writing.

      You will read two playthroughs of a text adventure. A narrator tells each scene and offers three choices; the player picks one and rolls a twenty-sided die against a target, and the narrator tells what came of it. The choices on offer, the rolls and what came of them are part of the story as it was played. The dice and the rules are not under review.

      Say which playthrough was the better story to have played. Answer in English.
    TEXT

    def initialize
      super(chat: understudy)
    end

    private
      def understudy
        command = Rails.configuration.x.narrator_command.presence
        Narrator::Understudy.new(command).with_model(MODEL) if command
      end
  end
end
