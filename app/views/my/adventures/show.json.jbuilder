json.(@adventure, :id, :title, :outcome, :locale, :scene_budget, :started_at, :ended_at)
json.multiplayer @adventure.multiplayer?
json.hero adventure_hero(@adventure)&.summary

json.scenes @scenes do |scene|
  json.(scene, :position, :title, :location, :narration, :finale)

  if (choice = scene.chosen_choice)
    json.choice do
      json.(choice, :label, :stat, :modifier, :target, :difficulty)
      json.by scene.active_player.name
    end
  else
    json.choice nil
  end

  if (roll = choice&.roll)
    json.roll { json.partial! "rolls/roll", roll: roll }
  else
    json.roll nil
  end
end

survivors = @adventure.survivors
json.party @adventure.party do |player|
  json.name player.name
  json.summary player.character&.summary
  json.alive survivors.include?(player)
end
