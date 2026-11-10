json.(scene, :position, :title, :location, :state, :finale, :narration, :effects)
json.stalled scene.stalled?
json.active_player scene.active_player.name

json.choices scene.choices do |choice|
  json.(choice, :id, :label, :stat, :modifier, :target, :difficulty)
  json.chosen choice.chosen?
end

if (roll = scene.roll)
  json.roll { json.partial! "rolls/roll", roll: roll }
else
  json.roll nil
end
