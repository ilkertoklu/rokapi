class Narrator
  class MalformedResponse < StandardError; end

  REWRITES = 2
  SCENE_WORDS = 90
  FINALE_WORDS = 120
  RESOLUTION_WORDS = 40
  LOCATION_WORDS = 5
  ADVENTURE_WORDS = 4
  LABEL_WORDS = 9
  REASON_WORDS = 10
  DIFFICULTY = 8..19
  STATUS_TURNS = 1..3
  STATUS_LIMIT = 2
  HEALTH_FLOOR = { narrow: -3, failure: -6, heavy: -9, catastrophe: -12 }.freeze

  # The scene header in scenes.css on the comp's 390px phone: one line of 18px Spectral SemiBold beside one dot per scene.
  HEADER_WIDTH = 390 - 2 * 22.4 - 12
  PROGRESS_DOT_PITCH = 7 + 6
  CURRENT_DOT_WIDTH = 9
  TITLE_GLYPH_WIDTH = 8.2

  def initialize(game_session)
    @game_session = game_session
    @cues = Cues.new(game_session, title_limit: title_limit)
  end

  def narrate_outcome(roll)
    return if roll.resolved?

    chat.with_schema OutcomeSchema
    resolution, effects = rewriting(@cues.outcome(roll)) { |prompt| ask_outcome(roll, prompt) }
    roll.resolve resolution: resolution, effects: effects
  end

  def narrate_scene(scene)
    return unless scene.narrating?

    chat.with_schema nil
    data, prose = rewriting(@cues.scene(scene)) { |prompt| ask_streaming(scene, prompt) }
    close_scene scene, data, prose
  end

  private
    def chat
      @chat ||= (@game_session.reload_chat || open_chat).with_caching
    end

    def open_chat
      @game_session.create_chat!(**voice).with_instructions(@cues.brief)
    end

    def voice
      if Rails.configuration.x.narrator_command.present?
        { model: Understudy::MODEL, provider: :understudy, assume_model_exists: true }
      else
        {}
      end
    end

    def rewriting(prompt)
      attempt = prompt

      REWRITES.times do
        return yield(attempt)
      rescue MalformedResponse => rejection
        Rails.logger.info "Narrator rewrite: #{rejection.message}"
        attempt = "Your reply was rejected: #{rejection.message}. Write the whole reply again."
      end

      yield attempt
    end

    def ask(prompt, &)
      if chat.messages.last&.role == "user"
        chat.complete(&)
      else
        chat.ask(prompt, &)
      end
    end

    def ask_outcome(roll, prompt)
      response = ask(prompt)
      record_call :outcome, response

      data = parsed(response)
      raise MalformedResponse, "structured output missing" unless data.is_a?(Hash)

      [ resolution_in(data), effects_in(data, roll) ]
    end

    def ask_streaming(scene, prompt)
      reply = Reply.new
      data = rejection = nil

      response = ask(prompt) do |chunk|
        next if rejection

        reply << chunk.content.to_s

        if data
          relay scene, reply.prose
        elsif (data = structure_in(reply))
          open_scene scene, data
        end
      rescue MalformedResponse => error
        rejection = error
      end

      record_call :scene, response
      raise rejection if rejection
      raise MalformedResponse, "structure block missing" if data.nil?

      [ data, prose_in(scene, reply.prose) ]
    end

    def relay(scene, prose)
      scene.update_column :narration, prose
      scene.broadcast_narration
    end

    def parsed(response)
      response.parsed
    rescue JSON::ParserError => error
      raise MalformedResponse, error.message
    end

    def structure_in(reply)
      reply.structure
    rescue JSON::ParserError => error
      raise MalformedResponse, error.message
    end

    def open_scene(scene, data)
      validate scene, data
      finale = data["finale"] == true

      ApplicationRecord.transaction do
        @game_session.update! title: data["adventure"] if names_the_adventure?(scene)
        @game_session.update! outcome: outcome_in(data) if finale
        scene.update! title: data["title"], location: data["location"], finale: finale
      end
    end

    def close_scene(scene, data, prose)
      ApplicationRecord.transaction do
        scene.update! narration: prose, state: scene.finale? ? :played : :choosing

        if scene.finale?
          @game_session.finish
        else
          create_choices scene, Array(data["choices"])
        end
      end
    end

    def validate(scene, data)
      raise MalformedResponse, "title missing" if data["title"].blank?
      within_header data["title"]
      within_words "the location", data["location"], LOCATION_WORDS
      within_words "the adventure", adventure_in(data), ADVENTURE_WORDS if names_the_adventure?(scene)

      choices = Array(data["choices"])

      if scene.active_player.character.hp.zero?
        defeat = data["finale"] == true && data["outcome"] == "defeat"
        raise MalformedResponse, "a downed character must meet defeat" unless defeat
      elsif data["finale"] == true
        outcome_in data
      elsif scene.position >= @game_session.scene_budget
        raise MalformedResponse, "scene #{scene.position} is the last one, so it must be the finale"
      elsif choices.size != 3
        raise MalformedResponse, "expected 3 choices"
      elsif choices.pluck("stat").uniq.size != 3
        raise MalformedResponse, "choices must use three distinct stats"
      else
        choices.each { |choice| validate_choice choice }
      end
    end

    def names_the_adventure?(scene)
      scene.first? && @game_session.quest.nil?
    end

    def adventure_in(data)
      data["adventure"].presence || raise(MalformedResponse, "the first scene must name the adventure")
    end

    def validate_choice(choice)
      within_words "the choice label", label_in(choice), LABEL_WORDS
      within_words "the difficulty reason", choice["difficulty_reason"], REASON_WORDS
      stat_in choice
      difficulty_in choice
    end

    def prose_in(scene, prose)
      raise MalformedResponse, "the narration is missing" if prose.blank?

      within_words "the narration", prose, scene.finale? ? FINALE_WORDS : SCENE_WORDS
    end

    def within_words(part, text, limit)
      count = text.to_s.split.size
      raise MalformedResponse, "#{part} runs #{count} words, at most #{limit} fit the screen: #{text.to_s.squish.inspect}" if count > limit

      text
    end

    def within_header(title)
      return if title.length <= title_limit

      raise MalformedResponse, "the title #{title.inspect} runs #{title.length} characters, at most #{title_limit} fit beside the progress dots"
    end

    def title_limit
      progress = PROGRESS_DOT_PITCH * (@game_session.scene_budget - 1) + CURRENT_DOT_WIDTH
      ((HEADER_WIDTH - progress) / TITLE_GLYPH_WIDTH).floor
    end

    def resolution_in(data)
      resolution = data["resolution"].presence || raise(MalformedResponse, "resolution missing")
      within_words "the resolution", resolution, RESOLUTION_WORDS
    end

    def effects_in(data, roll)
      effects = data["effects"].to_h
      statuses_lost = Array(effects["statuses_lost"])
      statuses_gained = earned_statuses(Array(effects["statuses_gained"]).map { |grant| status_in(grant) }, roll)
      within_status_limit roll.player.character, statuses_gained, statuses_lost

      { "hp" => effects["hp"].to_i.clamp(HEALTH_FLOOR.fetch(roll.grade, 0), 0),
        "items_gained" => Array(effects["items_gained"]).map { |grant| item_in(grant) },
        "items_lost" => Array(effects["items_lost"]),
        "statuses_gained" => statuses_gained,
        "statuses_lost" => statuses_lost }
    end

    def within_status_limit(character, gained, lost)
      kept = character.status_effects.map(&:name) - lost - gained.pluck(:name)
      return if gained.none? || kept.size + gained.size <= STATUS_LIMIT

      raise MalformedResponse, "the character would carry #{kept.size + gained.size} statuses, at most #{STATUS_LIMIT}"
    end

    def item_in(grant)
      kind = grant["kind"].presence_in(Item.kinds.keys) || raise(MalformedResponse, "unknown item kind #{grant["kind"].inspect}")
      instant = kind == "instant"

      { name: name_in(grant), kind: kind, description: grant["description"],
        hp_effect: instant ? grant["hp"].to_i : 0,
        uses_left: ([ grant["uses"].to_i, Item::MINIMUM_USES ].max if instant) }
    end

    def status_in(grant)
      turns = grant["turns"].to_i
      expires_when = grant["expires_when"].presence

      { name: name_in(grant), modifier: grant["modifier"].to_i.clamp(StatusEffect::MODIFIER_RANGE),
        turns_left: turns.positive? ? turns.clamp(STATUS_TURNS) : (StatusEffect::DEFAULT_TURNS if expires_when.nil?), expires_when: expires_when }
    end

    def name_in(grant)
      grant["name"].presence || raise(MalformedResponse, "nameless grant")
    end

    def earned_statuses(statuses, roll)
      return statuses if roll.critical?

      statuses.reject { |status| status[:modifier].positive? }
    end

    def outcome_in(data)
      data["outcome"].presence_in(GameSession.outcomes.keys) ||
        raise(MalformedResponse, "unknown outcome #{data["outcome"].inspect}")
    end

    def create_choices(scene, choices)
      character = scene.active_player.character

      choices.each do |choice|
        stat = stat_in(choice)

        scene.choices.create! label: label_in(choice), stat: stat, modifier: character.bonus_for(stat),
          target: difficulty_in(choice), difficulty_reason: choice["difficulty_reason"]
      end
    end

    def label_in(choice)
      choice["label"].presence || raise(MalformedResponse, "unlabeled choice")
    end

    def stat_in(choice)
      choice["stat"].presence_in(Character::Stat.keys) || raise(MalformedResponse, "unknown stat #{choice["stat"].inspect}")
    end

    def difficulty_in(choice)
      difficulty = Integer(choice["difficulty"], exception: false) || raise(MalformedResponse, "difficulty missing")
      raise MalformedResponse, "difficulty #{difficulty} is outside #{DIFFICULTY.min}-#{DIFFICULTY.max}" unless DIFFICULTY.cover?(difficulty)

      difficulty
    end

    def record_call(purpose, response)
      LlmCall.record game_session: @game_session, purpose: purpose, response: response
    end
end
