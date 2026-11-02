class Narrator
  class MalformedResponse < StandardError; end

  REWRITES = 2

  def self.table_name_prefix = "narrator_"

  def initialize(game_session)
    @game_session = game_session
    @cues = Cues.new(game_session)
  end

  def narrate_scene(scene)
    return unless scene.narrating?

    retelling(@cues.scene(scene)) { |cue| tell scene, cue }
  end

  def narrate_outcome(roll)
    return if roll.resolved?

    resolution = retelling(@cues.outcome(roll)) { |cue| resolve roll, cue }
    roll.resolve resolution: resolution.text, effects: resolution.effects
  end

  private
    def conversation
      @conversation ||= if (record = @game_session.reload_conversation)
        Voice.find(record.id)
      else
        Voice.create!(game_session: @game_session, **voice)
      end
    end

    def voice
      if Rails.configuration.x.narrator_command.present?
        { model: Understudy::MODEL, provider: :understudy, assume_model_exists: true }
      else
        {}
      end
    end

    def retelling(cue)
      rejection = nil

      REWRITES.times do
        return yield(cue_with(cue, rejection)).tap { settle cue if rejection }
      rescue MalformedResponse => error
        Rails.logger.info "Narrator rewrite: #{error.message}"
        forget_last_exchange
        rejection = error
      end

      yield(cue_with(cue, rejection)).tap { settle cue }
    end

    def cue_with(cue, rejection)
      rejection ? "#{cue}\n\nYour last reply was rejected: #{rejection.message}. Write the whole reply again." : cue
    end

    def forget_last_exchange
      @game_session.conversation.forget_last_exchange
      @conversation = nil
    end

    def settle(cue)
      @game_session.conversation.settle cue
      @conversation = nil
    end

    def speak(cue, schema: nil, &)
      conversation.with_schema schema
      conversation.messages.last&.role == "user" ? conversation.complete(&) : conversation.ask(cue, &)
    end

    def tell(scene, cue)
      reply = Reply.new
      telling = nil

      speak(cue) do |chunk|
        reply << chunk.content.to_s
        next if telling

        scene.stream reply.prose
        telling = Telling.open(scene, reply.structure)
      rescue MalformedResponse => error
        telling = error
      end

      raise telling if telling.is_a?(MalformedResponse)
      raise MalformedResponse, "structure block missing" if telling.nil?

      telling.close reply.prose
    end

    def resolve(roll, cue)
      Resolution.new roll, speak(cue, schema: OutcomeSchema).parsed
    rescue JSON::ParserError => error
      raise MalformedResponse, error.message
    end
end
