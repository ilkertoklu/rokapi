class Narrator::Brief
  LANGUAGES = { "en" => "English", "tr" => "Turkish" }.freeze

  def initialize(game_session)
    @game_session = game_session
  end

  def language
    LANGUAGES.fetch(@game_session.locale)
  end

  def quest
    GameSession::Quest[@game_session.quest]&.brief(locale: @game_session.locale) || "A surprise adventure: the world and the quest are yours to invent."
  end

  def tone
    I18n.with_locale(:en) { GameSession::Tone.fetch(@game_session.tone).label }
  end

  def scenes
    @game_session.scene_budget
  end

  def party
    I18n.with_locale(:en) { @game_session.party.map { |player| portrait(player) } }
  end

  def surprise?
    @game_session.quest.nil?
  end

  def title_limit
    Narrator.title_limit(scenes)
  end

  private
    def portrait(player)
      character = player.character
      klass = Character::Klass.fetch(character.klass)
      traits = [ Character::Race.fetch(character.race), klass, Character::Background.fetch(character.background) ]
      stats = Character::Stat.all.map { |stat| "#{stat.label} #{character.stats[stat.key]}" }.join(", ")
      gear = klass.starting_items(locale: @game_session.locale).map { |item| Item.new(item).summary }.join("; ")

      "#{player.name}: #{traits.map { |trait| "#{trait.label} (#{trait.description})" }.join(", ")}. " \
        "Health #{character.max_hp}. #{stats}. Sets out with #{gear}."
    end
end
