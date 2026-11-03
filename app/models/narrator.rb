class Narrator < RubyLLM::Agent
  class MalformedResponse < StandardError; end

  REWRITES = 2
  FENCE = "```"

  def self.table_name_prefix = "narrator_"

  chat_model Conversation
  caching
  instructions { prompt "instructions.#{chat.game_session.locale}", game: chat.game_session }

  def self.for(game_session)
    if (conversation = game_session.reload_conversation)
      new chat: conversation, persist_instructions: false
    elsif Rails.configuration.x.narrator_command.present?
      new chat: Conversation.create!(game_session: game_session, model: Understudy::MODEL, provider: :understudy, assume_model_exists: true)
    else
      new chat: Conversation.create!(game_session: game_session)
    end
  end

  def narrate_scene(scene)
    return unless scene.narrating?

    prose, data = rewriting RubyLLM.render_prompt("narrator/scene", scene: scene) do |cue|
      streamed = +""

      reply = speak(cue) do |chunk|
        streamed << chunk.content.to_s
        scene.stream streamed.split(FENCE, 2).first.to_s.sub(/`+\z/, "").strip
      end

      check_scene scene, *told(reply.content)
    end

    write_scene scene, prose, data
  end

  def narrate_outcome(roll)
    return if roll.resolved?

    resolution, effects = rewriting RubyLLM.render_prompt("narrator/outcome", roll: roll) do |cue|
      told speak(cue).content
    end

    roll.resolve resolution: resolution, effects: effects
  end

  private
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

    def check_scene(scene, prose, data)
      if (ending = scene.ending)
        raise MalformedResponse, "scene #{scene.position} is the last, and the story ends in #{ending}" unless data["outcome"] == ending
      else
        choices = Array(data["choices"])
        raise MalformedResponse, "the scene has no choices" if choices.empty?
        raise MalformedResponse, "every choice needs a label and one of the stats #{Character::Stat.keys.join(", ")}" unless choices.all? { |choice| playable?(choice) }
      end

      [ prose, data ]
    end

    def playable?(choice)
      choice.is_a?(Hash) && choice["label"].present? && Character::Stat.keys.include?(choice["stat"])
    end

    def write_scene(scene, prose, data)
      ending = scene.ending

      ApplicationRecord.transaction do
        game_session.update! title: data["adventure"] if scene.first? && game_session.quest.nil? && data["adventure"].present?
        scene.write narration: prose, effects: data, title: data["title"].presence, location: data["location"].presence, finale: ending.present?, state: ending ? :played : :choosing

        if ending
          game_session.update! outcome: ending
          game_session.finish
        else
          data["choices"].each do |choice|
            scene.choices.create! label: choice["label"], stat: choice["stat"], modifier: scene.active_player.character.bonus_for(choice["stat"]),
              target: choice["difficulty"].to_i
          end
        end
      end
    end
end
