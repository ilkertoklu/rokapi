class Narrator < RubyLLM::Agent
  class MalformedResponse < StandardError; end

  REWRITES = 2
  FENCE = "```"

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
      finale, title, choices = data["finale"] == true, data["title"].to_s, Array(data["choices"])
      raise MalformedResponse, "the title is missing" if title.blank?

      if names_the_adventure?(scene)
        raise MalformedResponse, "the first scene must name the adventure" if data["adventure"].blank?
      end

      if finale || scene.active_player.character.hp.zero? || scene.last?
        raise MalformedResponse, "scene #{scene.position} is the finale and the story ends in #{outcome_of(scene)}" unless finale && data["outcome"] == outcome_of(scene)
      else
        stats = choices.map { |choice| choice["stat"] }
        raise MalformedResponse, "expected 3 choices on 3 distinct stats" unless stats.size == 3 && stats.uniq.size == 3 && (stats - Character::Stat.keys).empty?

        choices.each do |choice|
          raise MalformedResponse, "a choice has no label" if choice["label"].blank?
          raise MalformedResponse, "difficulty #{choice["difficulty"].inspect} is outside #{Choice::DIFFICULTY.min}-#{Choice::DIFFICULTY.max}" unless Choice::DIFFICULTY.cover?(choice["difficulty"])
        end
      end

      [ prose, data ]
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
              target: choice["difficulty"]
          end
        end
      end
    end

    def outcome_of(scene)
      scene.active_player.character.hp.zero? ? "defeat" : game_session.verdict
    end

    def names_the_adventure?(scene)
      scene.first? && game_session.quest.nil?
    end
end
