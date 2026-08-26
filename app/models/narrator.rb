class Narrator
  class MalformedResponse < StandardError; end

  RECENT_SCENES = 2

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

    roll.resolve! resolution: resolution_in(data), effects: effects_in(data)
  end

  def continue!
    generate_scene if owed?
  end

  private
    def owed?
      scene = @game_session.current_scene
      return true if scene.nil? || scene.narrating? || scene.failed?

      scene.played? && !scene.finale? && scene.roll&.acknowledged?
    end

    def generate_scene
      scene = next_scene
      data, prose = ask_streaming(scene)
      close_scene! scene, data, prose
      fold_context_summary
    end

    def next_scene
      @game_session.scenes.unwritten.chronological.last ||
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
          open_scene! scene, data
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
    rescue JSON::ParserError
      repair(reply.json)
    end

    def repair(json)
      response = new_chat(model: helper_model).ask(<<~PROMPT)
        Aşağıdaki bozuk JSON'u düzelt. Yanıt olarak YALNIZCA geçerli JSON döndür, başka hiçbir şey yazma:

        #{json}
      PROMPT
      record_call :repair, response
      JSON.parse response.content.to_s.sub(/\A\s*```(?:json)?/, "").sub(/```\s*\z/m, "").strip
    rescue JSON::ParserError
      raise MalformedResponse, "repair failed"
    end

    def open_scene!(scene, data)
      validate! scene, data
      scene.update! title: data.fetch("title"), location: data["location"]
    rescue KeyError => error
      raise MalformedResponse, error.message
    end

    def close_scene!(scene, data, prose)
      finale = data["finale"] == true

      ApplicationRecord.transaction do
        @game_session.update! story_outline: data["plan"] if scene.position == 1 && data["plan"].present?
        scene.update! narration: prose, finale: finale, state: finale ? :played : :choosing

        if finale
          @game_session.finish! outcome_in(data)
        else
          create_choices scene, Array(data["choices"])
        end
      end
    end

    def validate!(scene, data)
      data.fetch("title")
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

    def effects_in(data)
      effects = data["effects"].to_h
      grants = Array(effects["items_gained"]) + Array(effects["statuses_gained"])
      raise MalformedResponse, "nameless grant" if grants.any? { |grant| grant["name"].blank? }

      effects
    end

    def outcome_in(data)
      data["outcome"].presence_in(GameSession.outcomes.keys) ||
        raise(MalformedResponse, "unknown outcome #{data["outcome"].inspect}")
    end

    def create_choices(scene, choices)
      character = scene.active_player.character

      choices.each do |choice|
        stat = choice.fetch("stat")
        raise MalformedResponse, "unknown stat #{stat}" unless Character::STAT_KEYS.include?(stat)

        scene.choices.create!(
          label: choice.fetch("label"),
          stat: stat,
          modifier: character.bonus_for(stat),
          difficulty: choice.fetch("difficulty").to_i.clamp(5, 19),
          difficulty_label: choice["difficulty_label"].presence_in(%w[kolay orta zor]) || "orta",
          difficulty_reason: choice["difficulty_reason"]
        )
      end
    end

    def fold_context_summary
      aged_out = scenes_aged_out_of_recent_window
      return if aged_out.empty?

      response = new_chat(model: helper_model).ask(@briefing.summary_prompt(aged_out))
      record_call :summary, response
      @game_session.update! context_summary: response.content.to_s,
                            context_summary_position: aged_out.last.position
    end

    def scenes_aged_out_of_recent_window
      recent = @game_session.scenes.written.chronological.last(RECENT_SCENES)
      return [] if recent.size < RECENT_SCENES

      @game_session.scenes.written.chronological
        .where(position: (@game_session.context_summary_position + 1)...recent.first.position).to_a
    end

    def helper_model
      Rails.configuration.x.llm.helper_model
    end

    def new_chat(model: nil, instructions: nil)
      chat = RubyLLM.chat(model: model)
      chat.with_instructions(instructions) if instructions
      chat
    end

    def record_call(purpose, response)
      LlmCall.record! game_session: @game_session, purpose: purpose, response: response
    end
end
