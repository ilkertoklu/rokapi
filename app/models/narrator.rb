class Narrator
  class MalformedResponse < StandardError; end

  def initialize(game_session)
    @game_session = game_session
    @briefing = Briefing.new(game_session)
  end

  def narrate_outcome(roll)
    return if roll.resolved?

    response = new_chat(instructions: @briefing.outcome_instructions).with_schema(OutcomeSchema).ask(@briefing.outcome_prompt(roll))
    record_call :outcome, response

    data = response.content
    raise MalformedResponse, "structured output missing" unless data.is_a?(Hash)

    roll.resolve resolution: resolution_in(data), effects: effects_in(data, roll)
  end

  def continue
    return unless owed?

    scene = next_scene
    plan if @game_session.story_bible.blank?
    generate_scene scene
  end

  private
    def owed?
      scene = @game_session.current_scene
      return true if scene.nil? || scene.narrating?

      scene.played? && !scene.finale? && scene.roll&.acknowledged?
    end

    def plan
      response = new_chat(instructions: @briefing.plan_instructions).with_schema(BibleSchema).ask(@briefing.plan_prompt)
      record_call :plan, response

      bible = response.content
      raise MalformedResponse, "story bible missing" unless bible.is_a?(Hash) && bible["beats"].present?

      @game_session.update! story_bible: bible
    end

    def generate_scene(scene)
      data, prose = ask_streaming(scene)
      close_scene scene, data, prose
    end

    def next_scene
      @game_session.scenes.narrating.chronological.last ||
        @game_session.scenes.create!(position: (@game_session.scenes.maximum(:position) || 0) + 1,
                                     active_player: @game_session.players.order(:created_at).first)
    end

    def ask_streaming(scene)
      reply = Reply.new
      data = nil
      visible = 0
      chat = new_chat(instructions: @briefing.scene_instructions)

      response = chat.ask(@briefing.scene_prompt(scene)) do |chunk|
        reply << chunk.content.to_s

        if data
          visible = relay(scene, reply.prose, visible)
        elsif (data = structure_in(reply))
          open_scene scene, data
        end
      end

      record_call :scene, response
      raise MalformedResponse, "structure block missing" if data.nil?

      [ data, reply.prose ]
    end

    def relay(scene, prose, visible)
      return visible if prose.length <= visible

      scene.update_column :narration, prose
      scene.broadcast_narration prose[visible..]
      prose.length
    end

    def structure_in(reply)
      reply.structure
    rescue JSON::ParserError => error
      raise MalformedResponse, error.message
    end

    def open_scene(scene, data)
      validate scene, data
      scene.update! title: data["title"], location: data["location"]
    end

    def close_scene(scene, data, prose)
      finale = data["finale"] == true

      ApplicationRecord.transaction do
        scene.update! narration: prose, finale: finale, state: finale ? :played : :choosing

        if finale
          @game_session.finish outcome_in(data)
        else
          create_choices scene, Array(data["choices"])
        end
      end
    end

    def validate(scene, data)
      raise MalformedResponse, "title missing" if data["title"].blank?

      choices = Array(data["choices"])

      if scene.active_player.character.hp.zero?
        defeat = data["finale"] == true && data["outcome"] == "defeat"
        raise MalformedResponse, "a downed character must meet defeat" unless defeat
      elsif data["finale"] == true
        outcome_in data
      elsif choices.size != 3
        raise MalformedResponse, "expected 3 choices"
      elsif choices.pluck("stat").uniq.size != 3
        raise MalformedResponse, "choices must use three distinct stats"
      end
    end

    def resolution_in(data)
      data["resolution"].presence || raise(MalformedResponse, "resolution missing")
    end

    def effects_in(data, roll)
      effects = data["effects"].to_h

      { "hp" => effects["hp"].to_i,
        "items_gained" => Array(effects["items_gained"]).map { |grant| item_in(grant) },
        "items_lost" => Array(effects["items_lost"]),
        "statuses_gained" => earned_statuses(Array(effects["statuses_gained"]).map { |grant| status_in(grant) }, roll),
        "statuses_lost" => Array(effects["statuses_lost"]) }
    end

    def item_in(grant)
      kind = grant["kind"].presence_in(Item.kinds.keys) || raise(MalformedResponse, "unknown item kind #{grant["kind"].inspect}")

      { "name" => name_in(grant), "kind" => kind, "description" => grant["description"].presence,
        "hp_effect" => (kind == "instant" ? grant["hp"].to_i : 0),
        "uses_left" => ([ grant["uses"].to_i, 1 ].max if kind == "instant") }
    end

    def status_in(grant)
      turns = grant["turns"].to_i
      expires_when = grant["expires_when"].presence

      { "name" => name_in(grant), "modifier" => grant["modifier"].to_i.clamp(-2, 2),
        "turns_left" => (turns.positive? ? turns : (2 if expires_when.nil?)), "expires_when" => expires_when }
    end

    def name_in(grant)
      grant["name"].presence || raise(MalformedResponse, "nameless grant")
    end

    def earned_statuses(statuses, roll)
      return statuses if roll.grade == :critical

      statuses.reject { |status| status["modifier"].positive? }
    end

    def outcome_in(data)
      data["outcome"].presence_in(GameSession.outcomes.keys) ||
        raise(MalformedResponse, "unknown outcome #{data["outcome"].inspect}")
    end

    def create_choices(scene, choices)
      character = scene.active_player.character

      choices.each do |choice|
        stat = stat_in(choice)

        scene.choices.create!(
          label: choice["label"].presence || raise(MalformedResponse, "unlabeled choice"),
          stat: stat,
          modifier: character.bonus_for(stat),
          difficulty: difficulty_in(choice),
          difficulty_label: choice["difficulty_label"].presence_in(%w[kolay orta zor]) || "orta",
          difficulty_reason: choice["difficulty_reason"]
        )
      end
    end

    def stat_in(choice)
      choice["stat"].presence_in(Character::STAT_KEYS) || raise(MalformedResponse, "unknown stat #{choice["stat"].inspect}")
    end

    def difficulty_in(choice)
      difficulty = Integer(choice["difficulty"], exception: false) || raise(MalformedResponse, "difficulty missing")
      difficulty.clamp(5, 19)
    end

    def new_chat(instructions:)
      RubyLLM.chat.with_instructions(instructions)
    end

    def record_call(purpose, response)
      LlmCall.record! game_session: @game_session, purpose: purpose, response: response
    end
end
