class Narrator::Cues
  LANGUAGES = { "en" => "English", "tr" => "Turkish" }.freeze
  GRADE_NOTES = {
    critical: "natural 20",
    brilliant: "target beaten by %{margin}",
    narrow: "by a hair",
    heavy: "%{margin} under the target",
    catastrophe: "natural 1"
  }.freeze

  def initialize(game_session, title_limit:)
    @game_session = game_session
    @title_limit = title_limit
  end

  def brief
    in_english do
      RubyLLM.render_prompt "narrator/brief",
        language: LANGUAGES.fetch(@game_session.locale), quest: quest, tone: GameSession::Tone.fetch(@game_session.tone).directive,
        scenes: budget, party: @game_session.party.map { |player| portrait(player) }, surprise: surprise?, title_limit: @title_limit
    end
  end

  def scene(scene)
    name = scene.active_player.name

    if scene.active_player.character.hp.zero?
      "#{name} has collapsed, their health spent. Scene #{scene.position} of #{budget} is the finale: close the story in defeat."
    elsif scene.position >= budget
      "Scene #{scene.position} of #{budget}, the finale: close the story with victory or defeat."
    else
      turn = " #{name}'s turn." if @game_session.multiplayer?
      "Scene #{scene.position} of #{budget}.#{turn} Write the #{scene.first? ? "first" : "next"} scene."
    end
  end

  def outcome(roll)
    in_english do
      character = roll.player.character
      status = " #{format('%+d', roll.status_modifier)} (status)" unless roll.status_modifier.zero?

      [ "#{roll.player.name} chose \"#{roll.choice.label}\" and rolled #{roll.value} #{format('%+d', roll.modifier)}#{status} = #{roll.total} " \
          "against #{roll.target}: #{grade(roll)}.",
        used_items(roll),
        "#{roll.player.name} has #{character.hp}/#{character.max_hp} health. Resolve it." ].compact.join(" ")
    end
  end

  private
    def in_english(&)
      I18n.with_locale(:en, &)
    end

    def budget
      @game_session.scene_budget
    end

    def surprise?
      @game_session.quest.nil?
    end

    def quest
      GameSession::Quest[@game_session.quest]&.brief(locale: @game_session.locale) ||
        "A surprise adventure: the world and the quest are yours to invent, away from dragons, lost princesses and chosen ones."
    end

    def portrait(player)
      character = player.character
      traits = [ Character::Race.fetch(character.race), Character::Klass.fetch(character.klass), Character::Background.fetch(character.background) ]
      stats = Character::Stat.all.map { |stat| "#{stat.label} #{character.stats[stat.key]}" }.join(", ")
      items = character.items.carried.map(&:summary).join("; ").presence || "nothing"

      "#{player.name}: #{traits.map { |trait| "#{trait.label} (#{trait.description})" }.join(", ")}. " \
        "Health #{character.max_hp}. #{stats}. Carries #{items}."
    end

    def grade(roll)
      note = GRADE_NOTES[roll.grade]
      note ? "#{roll.grade_label} (#{note % { margin: roll.margin.abs }})" : roll.grade_label
    end

    def used_items(roll)
      used = roll.player.character.items.used_since(roll.scene.created_at)
      return if used.none?

      "Before rolling, #{roll.player.name} used #{used.map { |item| "#{item.name} (#{format('%+d', item.hp_effect)} health)" }.join(" and ")}; " \
        "that health is already applied and the item is gone, so it belongs in neither hp nor items_lost."
    end
end
