class Narrator < RubyLLM::Agent
  class MalformedResponse < StandardError; end

  REWRITES = 2
  FENCE = "```"

  def self.table_name_prefix = "narrator_"

  chat_model Conversation
  caching
  instructions { prompt "instructions.#{chat.game_session.locale}", game: chat.game_session }

  def self.for(game_session)
    game_session.plan_story unless game_session.plan?

    if (conversation = game_session.reload_conversation)
      new chat: conversation, persist_instructions: false
    else
      new chat: game_session.create_conversation!
    end
  end

  def narrate_scene(scene)
    return unless scene.narrating?

    prose, data = rewriting cue_from("scene", scene: scene) do |cue|
      streamed = +""

      reply = speak(cue) do |chunk|
        streamed << chunk.content.to_s
        scene.stream streamed.split(FENCE, 2).first.to_s.sub(/`+\z/, "").strip
      end

      check_scene(*told(reply.content))
    end

    scene.write narration: prose, effects: data
  end

  def narrate_outcome(roll)
    return if roll.resolved?

    resolution, effects = rewriting cue_from("outcome", roll: roll) do |cue|
      check_outcome roll, *told(speak(cue).content)
    end

    roll.resolve resolution: resolution, effects: effects
  end

  private
    def cue_from(template, **locals)
      RubyLLM.render_prompt("narrator/#{template}", **locals).squeeze("\n").strip
    end

    def rewriting(cue)
      prompt = cue
      rewrites = 0

      begin
        yield prompt
      rescue MalformedResponse, JSON::ParserError => error
        Rails.logger.info "Narrator rejected a reply: #{error.message}"
        chat.forget_last_exchange
        raise MalformedResponse, error.message if (rewrites += 1) > REWRITES

        prompt = "#{cue}\nYour last reply was rejected: #{error.message}. Write the whole reply again."
        retry
      end
    end

    def speak(cue, &)
      messages.last&.role == "user" ? complete(&) : ask(cue, &)
    end

    def game_session
      chat.game_session
    end

    def told(content)
      prose, structure = content.to_s.split(FENCE, 3).map(&:strip)
      raise MalformedResponse, "the #{FENCE}json block is missing" if structure.nil?
      raise MalformedResponse, "the narration is missing" if prose.empty?

      data = JSON.parse(structure.delete_prefix("json"))
      raise MalformedResponse, "the #{FENCE}json block must hold one object" unless data.is_a?(Hash)

      [ prose, data ]
    end

    def check_scene(prose, data)
      choices = Array(data["choices"])
      raise MalformedResponse, "the scene has no choices" if choices.empty?
      raise MalformedResponse, "every choice needs a label and one of the stats #{Character::Stat.keys.join(", ")}" unless choices.all? { |choice| playable?(choice) }

      [ prose, data ]
    end

    def check_outcome(roll, prose, data)
      ending = roll.ending_with(data)

      if data["outcome"] != ending
        raise MalformedResponse, ending ? %(the story ends with this roll, in #{ending}: tell the ending and add "outcome": "#{ending}" to the block) : "the story goes on after this roll, so the block has no outcome"
      end

      [ prose, data ]
    end

    def playable?(choice)
      choice.is_a?(Hash) && choice["label"].present? && Character::Stat.keys.include?(choice["stat"])
    end
end
