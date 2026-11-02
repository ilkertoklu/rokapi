class Narrator::Briefing
  GRADE_NOTES = {
    critical: "natural 20",
    brilliant: "target beaten by %{margin}",
    narrow: "by a hair",
    heavy: "%{margin} under the target",
    catastrophe: "natural 1"
  }.freeze

  def initialize(game_session)
    @game_session = game_session
  end

  def plan_prompt
    compose do
      [ mission_block, character_portrait, "SCENE COUNT: #{@game_session.scene_budget}. The beat list is exactly #{@game_session.scene_budget} lines.",
        "Write the story bible." ]
    end
  end

  def outcome_prompt(roll)
    compose do
      [ mission_block, bible_block, character_block(roll.scene), party_block(roll.scene), used_items_block(roll),
        history_block, roll_block(roll), "Resolve this roll." ]
    end
  end

  def scene_prompt(scene)
    compose do
      [ mission_block, bible_block, character_block(scene), party_block(scene), history_block, pacing_block(scene), action_block ]
    end
  end

  private
    def compose
      I18n.with_locale(:en) { yield.compact.join("\n\n") }
    end

    def mission_block
      brief = GameSession::Quest[@game_session.quest]&.brief(locale: @game_session.locale) ||
        "Surprise adventure: the world and the quest are yours to invent."
      "QUEST FRAME: #{brief}\nTONE: #{GameSession::Tone.fetch(@game_session.tone).directive}"
    end

    def bible_block
      return if @game_session.story_bible.blank?

      antagonist = @game_session.story_antagonist.to_h
      ally = @game_session.story_ally.to_h
      <<~TEXT.strip
        STORY BIBLE (hidden, never told to the player, lived through the scenes):
        Adventure: #{@game_session.story_title}. #{@game_session.story_premise}
        Personal stake: #{@game_session.story_personal_stake}
        Opposing force: #{antagonist["name"]} — wants: #{antagonist["want"]} Method: #{antagonist["method"]} First trace: #{antagonist["first_sign"]}
        Ally: #{ally["name"]} — wants: #{ally["want"]} Secret: #{ally["secret"]}
        Twist: #{@game_session.story_twist}
        The finale's question: #{@game_session.story_finale_question}
        Victory: #{@game_session.story_victory}
        Defeat: #{@game_session.story_defeat}
      TEXT
    end

    def pacing_block(scene)
      [ "SCENE: #{scene.position}/#{@game_session.scene_budget}", beat_line(scene), stage_directive(scene) ].compact.join("\n")
    end

    def beat_line(scene)
      beat = Array(@game_session.story_beats)[scene.position - 1]
      "BEAT: #{beat}" if beat.present?
    end

    def stage_directive(scene)
      budget = @game_session.scene_budget

      if scene.active_player.character.hp.zero?
        "THE CHARACTER HAS COLLAPSED: their health is spent, so this scene is the FINALE and its outcome is \"defeat\"."
      elsif scene.position >= budget
        "This scene is the FINALE: it closes the story with \"victory\" or \"defeat\"."
      elsif scene.position == budget - 1
        "The next scene is the finale."
      end
    end

    def character_block(scene)
      character = scene.active_player.character
      stats = Character::Stat.all.map { |stat| "#{stat.label} #{character.stats[stat.key]}" }.join(", ")
      [ "CHARACTER: #{character.name} — #{character.summary}. Health #{character.hp}/#{character.max_hp}. Abilities: #{stats}.",
        inventory_line(character), statuses_line(character) ].compact.join("\n")
    end

    def character_portrait
      if @game_session.multiplayer?
        "THE PARTY (#{party.size} players, taking turns):\n" +
          party.map { |player| "#{player.name} — #{traits_of(player.character)}\n#{inventory_line(player.character)}" }.join("\n")
      else
        character = @game_session.host.character
        "THE PLAYER'S CHARACTER: #{traits_of(character)}\n#{inventory_line(character)}"
      end
    end

    def traits_of(character)
      [ Character::Race.fetch(character.race), Character::Klass.fetch(character.klass), Character::Background.fetch(character.background) ]
        .map { |trait| "#{trait.label}: #{trait.description}" }.join(" ")
    end

    def party_block(scene)
      return unless @game_session.multiplayer?

      name = scene.active_player.name
      members = party.map { |player| "#{player.name} (#{player.character.summary}, health #{player.character.hp}/#{player.character.max_hp})" }

      "THE PARTY travels together and takes turns: #{members.join("; ")}.\n" \
        "THIS TURN: #{name}. Only #{name} chooses and rolls."
    end

    def party
      @party ||= @game_session.party.to_a
    end

    def inventory_line(character)
      items = character.items.carried
      "INVENTORY: #{items.any? ? items.map(&:summary).join("; ") : "empty"}"
    end

    def statuses_line(character)
      statuses = character.status_effects
      "STATUS EFFECTS: #{statuses.map(&:summary).join("; ")}" if statuses.any?
    end

    def used_items_block(roll)
      used = roll.player.character.items.used_since(roll.scene.created_at)
      return if used.none?

      "ITEM USED: #{used.map { |item| "#{item.name} (#{format('%+d', item.hp_effect)} health)" }.join("; ")} — its health is already applied and it is off the inventory, so it belongs in neither hp nor items_lost."
    end

    def history_block
      scenes = @game_session.scenes.played.chronological.includes(roll: [ :choice, { player: :user } ])
      return if scenes.none?

      "THE STORY SO FAR (scene by scene, with the player's choice and the roll):\n" + scenes.map { |scene| history_entry(scene) }.join("\n\n")
    end

    def history_entry(scene)
      entry = "[#{scene.position}] #{scene.title} @ #{scene.location}\n#{scene.narration}"
      roll = scene.roll
      return entry if roll.nil? || !roll.resolved?

      chooser = " by #{roll.player.name}" if @game_session.multiplayer?
      "#{entry}\n→ Choice#{chooser}: \"#{roll.choice.label}\" — #{grade_label(roll)}. #{roll.resolution}"
    end

    def roll_block(roll)
      status = " #{format('%+d', roll.status_modifier)} (status)" unless roll.status_modifier.zero?
      <<~TEXT
        ROLL RESULT: "#{roll.choice.label}" was chosen.
        d20=#{roll.value} #{format('%+d', roll.modifier)}#{status} = #{roll.total}, target #{roll.target} → #{grade_label(roll)}.
      TEXT
    end

    def grade_label(roll)
      note = GRADE_NOTES[roll.grade]
      note ? "#{roll.grade_label} (#{note % { margin: roll.margin.abs }})" : roll.grade_label
    end

    def action_block
      @game_session.rolls.exists? ? "Write the next scene." : "Write the first scene."
    end
end
