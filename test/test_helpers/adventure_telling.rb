module AdventureTelling
  def tell_adventure(game_session, title:, turns:, outcome: "victory", ended_at: Time.current)
    game_session.update! title: title, started_at: ended_at - 25.minutes

    turns.each.with_index(1) do |(player, scene_title, label, value), position|
      scene = game_session.scenes.create! position: position, active_player: player, state: :played, finale: position == turns.size,
        title: scene_title, location: "Whitebend", narration: "#{scene_title} opens before you."
      scene.choices.create! label: "Walk away from #{scene_title}", stat: "wisdom", target: 10
      choice = scene.choices.create! label: label, stat: "strength", modifier: 2, target: 10, chosen_at: ended_at
      choice.create_roll! player: player, value: value, resolution: "What came of #{label.downcase}."
    end

    game_session.update! outcome: outcome, ended_at: ended_at
  end

  def ready_warrior(player)
    player.create_character! race: "human", klass: "warrior", background: "soldier",
      stats: Character::Klass.fetch("warrior").base_stats.merge("strength" => 16, "constitution" => 15, "charisma" => 14)
  end
end
