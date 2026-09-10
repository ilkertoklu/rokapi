class Narrator::Briefing
  GRADE_NOTES = {
    critical: "natural 20, an exceptional moment",
    brilliant: "target beaten by %{margin}",
    narrow: "by a hair",
    heavy: "%{margin} under the target",
    catastrophe: "natural 1, the worst that can happen"
  }.freeze

  def initialize(game_session)
    @game_session = game_session
  end

  def plan_prompt
    [ mission_block, character_portrait, "SCENE COUNT: #{@game_session.scene_budget}. The beat list is exactly #{@game_session.scene_budget} lines.",
      "Write the story bible." ].join("\n\n")
  end

  def outcome_prompt(roll)
    [ mission_block, bible_block, character_block(roll.scene), used_items_block(roll),
      history_block, roll_block(roll), missing_healing_block(roll), "Resolve this result." ].compact.join("\n\n")
  end

  def scene_prompt(scene)
    [ mission_block, bible_block, character_block(scene), history_block, repetition_block, variety_block,
      wounded_block(scene), pacing_block(scene), action_block ].compact.join("\n\n")
  end

  private
    def mission_block
      brief = GameSession::Quest[@game_session.quest]&.brief ||
        "Surprise adventure: build an unknown, original world and quest, and drop the player into the middle of the story in the first scene."
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

    def repetition_block
      stats = @game_session.rolls.order(id: :desc).limit(3).pluck("choices.stat")
      return unless stats.size == 3 && stats.uniq.size == 1

      label = Character::Stat.fetch(stats.first).label
      "REPETITION: The player has used #{label} three times in a row. The world adapts: in this scene either close the #{label} road or make it markedly harder."
    end

    def variety_block
      recent = @game_session.scenes.played.chronological.last(2).flat_map(&:choices)
      return if recent.empty?

      easy = recent.select(&:easy?).map(&:stat).uniq
      hard = recent.select(&:hard?).map(&:stat).uniq
      "VARIETY: The choices in the last scenes were: #{recent.map { |choice| %("#{choice.label}") }.join(", ")}. " \
        "Do not write their pattern again. The easy choice was on #{stat_labels(easy)} and the hard choice on #{stat_labels(hard)}. In this scene put the easy and the hard choice on other stats."
    end

    def stat_labels(stats)
      stats.map { |stat| Character::Stat.fetch(stat).label }.join("/").presence || "—"
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
        "THE CHARACTER HAS COLLAPSED: their health is spent. This scene is the FINALE and it is a defeat. Tell their fall in at most 2 short paragraphs and 110 words. #{closing_rules} finale=true, outcome=\"defeat\", produce no choices."
      elsif scene.position >= budget
        "This scene is the FINALE: close the story in at most 2 short paragraphs and 120 words. The finale does not make the player act again and does not retell the climax resolution, it shows what came after that result. #{tally_line} Answer the finale's question with what the player actually did: if the victory condition was met the outcome is \"victory\", if not it is \"defeat\", and both come at a price. If the climax roll failed there is no clean victory: either defeat, or only a part of the victory condition, achieved with a visible loss (a person, a place, a relationship). #{closing_rules} finale=true, produce no choices."
      elsif scene.position == budget - 1
        "CLIMAX: the opposing force is met face to face and the danger is physical. All three choices demand a price, and even the easy one sacrifices something. The choice in this scene sets the colour of the finale, and the next scene is the finale."
      elsif scene.first?
        "OPENING: the player lands in the middle of events. The personal stake is established in one sentence in this scene (a name, a memory, a debt), the first trace of the opposing force shows, and the goal is clear."
      elsif scene.position == midpoint
        "MIDPOINT: the twist comes out in this scene, and there is no going back after it."
      elsif scene.position > midpoint
        "ESCALATION: the pace rises and the costs grow. The ally's secret and the face of the opposing force draw closer."
      else
        "DEVELOPMENT: bring a new complication, a piece of knowledge or a cost, and make the player take a concrete step towards the goal."
      end
    end

    def tally_line
      rolls = @game_session.rolls.order(:id).to_a
      return if rolls.empty?

      "ROLL TALLY: #{rolls.count(&:success?)} successes, #{rolls.count { |roll| !roll.success? }} failures. The climax roll was #{grade_label(rolls.last)}."
    end

    def closing_rules
      "The closing pays off what was set up: the personal stake is answered in one sentence and the player is present in the finale (someone speaks to them, or something is left to them), the fate of the opposing force and of the ally each show in a sentence, an image from the opening returns (the image itself comes back, do not say \"the one from the first scene\"), and the last sentence is a single landed image. Do not write an open-ended closing like \"one day\", \"in time\" or \"the adventure will go on\"."
    end

    def midpoint
      (@game_session.scene_budget / 2.0).ceil
    end

    def missing_healing_block(roll)
      scene = roll.scene
      character = scene.active_player.character
      return if scene.position < 2 || character.sturdy? || character.items.healing.any?
      return if last_outcome_granted_item?(roll)

      "MISSING: The character has no healing item and the game is waiting for one. If there is the slightest opening in this resolution " \
        "(a bag, a chest, wreckage, a body, a reward, a friendly hand), give them a healing potion: instant, +6..+8 health, 1 use. " \
        "This licence holds for every grade: an ordinary success can find a potion too."
    end

    def last_outcome_granted_item?(roll)
      previous = @game_session.rolls.where.not(id: roll.id).order(:id).last
      previous.present? && previous.items_gained.any?
    end

    def wounded_block(scene)
      character = scene.active_player.character
      return unless character.wounded?

      "BADLY WOUNDED: The character's health is #{character.hp}/#{character.max_hp}. The world sees it: " \
        "let the narration carry the exhaustion, and let one of the choices open onto a breather, healing, or a cautious road."
    end

    def character_block(scene)
      character = scene.active_player.character
      stats = Character::Stat.all.map { |stat| "#{stat.label} #{character.stats[stat.key]}" }.join(", ")
      [ "CHARACTER: #{character.user.name} — #{character.summary}. Health #{character.hp}/#{character.max_hp}. Abilities: #{stats}.",
        inventory_line(character), statuses_line(character) ].compact.join("\n")
    end

    def character_portrait
      character = @game_session.host.character
      traits = [ Character::Race.fetch(character.race), Character::Klass.fetch(character.klass), Character::Background.fetch(character.background) ]
        .map { |trait| "#{trait.label}: #{trait.description}" }.join(" ")
      "THE PLAYER'S CHARACTER: #{traits}\n#{inventory_line(character)}"
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

      "ITEM USED: #{used.map { |item| "#{item.name} (#{format('%+d', item.hp_effect)} health)" }.join("; ")} — the health is already applied and the item is off the inventory. Let it show in the narration that it was drunk, and do not write it to hp or items_lost again."
    end

    def history_block
      scenes = @game_session.scenes.played.chronological.includes(roll: :choice)
      return if scenes.none?

      "THE STORY SO FAR (scene by scene, with the player's choice and the roll):\n" + scenes.map { |scene| history_entry(scene) }.join("\n\n")
    end

    def history_entry(scene)
      entry = "[#{scene.position}] #{scene.title} @ #{scene.location}\n#{scene.narration}"
      roll = scene.roll
      return entry if roll.nil? || !roll.resolved?

      "#{entry}\n→ Choice: \"#{roll.choice.label}\" — #{grade_label(roll)}. #{roll.resolution}"
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
      roll = @game_session.rolls.order(:id).last
      return "Write the first scene." if roll.nil?

      "The last resolution was shown to the player: do not stage what happened again, write what follows from where it left off."
    end
end
