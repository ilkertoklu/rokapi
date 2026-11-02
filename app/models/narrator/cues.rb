class Narrator::Cues
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
