class Judgement::Playthrough
  def initialize(game_session)
    @game_session = game_session
  end

  def to_s
    [ heading, *scenes.map { |scene| scene_entry(scene) }, ending ].compact.join("\n\n")
  end

  private
    def heading
      characters = @game_session.party.map { |player| "#{player.name} (#{player.character.summary})" }
      "#{@game_session.title}\nPlayed by #{characters.to_sentence}."
    end

    def scenes
      @game_session.scenes.chronological.includes(:choices, roll: { player: :user })
    end

    def scene_entry(scene)
      [ "SCENE #{scene.position}: #{scene.title} @ #{scene.location}\n#{scene.narration}", options(scene), turn(scene.roll) ].compact.join("\n\n")
    end

    def options(scene)
      return if scene.choices.empty?

      "Options:\n" + scene.choices.map { |choice| "- #{choice.label} (#{Character::Stat.fetch(choice.stat).label}, target #{choice.target})" }.join("\n")
    end

    def turn(roll)
      return unless roll&.resolved?

      chooser = " by #{roll.player.name}" if @game_session.multiplayer?
      status = " #{format('%+d', roll.status_modifier)} status" unless roll.status_modifier.zero?
      [ "Chosen#{chooser}: #{roll.choice.label}. Rolled #{roll.value} #{format('%+d', roll.modifier)}#{status} = #{roll.total} against #{roll.target}: #{roll.grade_label.downcase}.",
        roll.resolution, effects(roll) ].compact.join("\n")
    end

    def effects(roll)
      changes = []
      changes << "health #{format('%+d', roll.hp_change)}" unless roll.hp_change.to_i.zero?
      changes << "gained #{roll.items_gained.pluck("name").to_sentence}" if roll.items_gained.any?
      changes << "lost #{roll.items_lost.to_sentence}" if roll.items_lost.any?
      changes << "now #{roll.statuses_gained.pluck("name").to_sentence}" if roll.statuses_gained.any?
      changes << "no longer #{roll.statuses_lost.to_sentence}" if roll.statuses_lost.any?
      "(#{changes.join("; ")})" if changes.any?
    end

    def ending
      "THE END: #{@game_session.outcome}" if @game_session.outcome
    end
end
