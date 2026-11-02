class Narrator < RubyLLM::Agent
  class MalformedResponse < StandardError; end

  REWRITES = 2
  FENCE = "```"
  WORDS = { scene: 90, finale: 120, resolution: 40, location: 5, adventure: 4, label: 9, reason: 10 }.freeze

  def self.table_name_prefix = "narrator_"

  chat_model Conversation
  caching
  instructions game: -> { chat.game_session }

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

      check_scene scene, reply.content
    end

    write_scene scene, prose, data
  end

  def narrate_outcome(roll)
    return if roll.resolved?

    data = rewriting RubyLLM.render_prompt("narrator/outcome", roll: roll) do |cue|
      check_outcome speak(cue, schema: OutcomeSchema).parsed
    end

    roll.resolve resolution: data["resolution"], effects: data["effects"]
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

    def speak(cue, schema: nil, &)
      with_schema schema
      messages.last&.role == "user" ? complete(&) : ask(cue, &)
    end

    def game_session
      chat.game_session
    end

    def check_scene(scene, content)
      prose, structure = content.to_s.split(FENCE, 3).map(&:strip)
      raise MalformedResponse, "the #{FENCE}json block is missing" if structure.nil?

      data = JSON.parse(structure.delete_prefix("json"))
      raise MalformedResponse, "the #{FENCE}json block must hold one object" unless data.is_a?(Hash)

      finale, title, choices = data["finale"] == true, data["title"].to_s, Array(data["choices"])
      raise MalformedResponse, "the narration is missing" if prose.empty?
      fit "the narration", prose, finale ? :finale : :scene
      raise MalformedResponse, "the title is missing" if title.blank?
      raise MalformedResponse, "the title #{title.inspect} runs #{title.length} characters, at most #{game_session.title_length} fit beside the progress dots" if title.length > game_session.title_length
      fit "the location", data["location"], :location

      if names_the_adventure?(scene)
        raise MalformedResponse, "the first scene must name the adventure" if data["adventure"].blank?
        fit "the adventure", data["adventure"], :adventure
      end

      if scene.active_player.character.hp.zero?
        raise MalformedResponse, "a downed character must meet defeat" unless finale && data["outcome"] == "defeat"
      elsif finale
        raise MalformedResponse, "unknown outcome #{data["outcome"].inspect}" unless GameSession.outcomes.key?(data["outcome"])
      elsif scene.last?
        raise MalformedResponse, "scene #{scene.position} is the last one, so it must be the finale"
      else
        stats = choices.map { |choice| choice["stat"] }
        raise MalformedResponse, "expected 3 choices on 3 distinct stats" unless stats.size == 3 && stats.uniq.size == 3 && (stats - Character::Stat.keys).empty?

        choices.each do |choice|
          raise MalformedResponse, "a choice has no label" if choice["label"].blank?
          fit "the choice label", choice["label"], :label
          fit "the difficulty reason", choice["difficulty_reason"], :reason
          raise MalformedResponse, "difficulty #{choice["difficulty"].inspect} is outside #{Choice::DIFFICULTY.min}-#{Choice::DIFFICULTY.max}" unless Choice::DIFFICULTY.cover?(choice["difficulty"])
        end
      end

      [ prose, data ]
    end

    def check_outcome(data)
      raise MalformedResponse, "the resolution is missing" unless data.is_a?(Hash) && data["resolution"].present?
      fit "the resolution", data["resolution"], :resolution

      data
    end

    def fit(part, text, limit)
      count = text.to_s.split.size
      raise MalformedResponse, "#{part} runs #{count} words, at most #{WORDS[limit]} fit the screen: #{text.to_s.squish.inspect}" if count > WORDS[limit]
    end

    def write_scene(scene, prose, data)
      finale = data["finale"] == true

      ApplicationRecord.transaction do
        game_session.update! title: data["adventure"] if names_the_adventure?(scene)
        scene.update! title: data["title"], location: data["location"], narration: prose, finale: finale, state: finale ? :played : :choosing

        if finale
          game_session.update! outcome: data["outcome"]
          game_session.finish
        else
          data["choices"].each do |choice|
            scene.choices.create! label: choice["label"], stat: choice["stat"], modifier: scene.active_player.character.bonus_for(choice["stat"]),
              target: choice["difficulty"], difficulty_reason: choice["difficulty_reason"]
          end
        end
      end
    end

    def names_the_adventure?(scene)
      scene.first? && game_session.quest.nil?
    end
end
