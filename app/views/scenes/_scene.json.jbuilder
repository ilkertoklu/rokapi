json.(scene, :position, :title, :location, :state, :finale, :narration)
json.stalled scene.stalled?

json.choices scene.choices.order(:id) do |choice|
  json.(choice, :id, :label, :stat, :modifier, :target, :difficulty, :difficulty_reason)
  json.chosen choice.chosen?
end

if (roll = scene.roll)
  json.roll { json.partial! "rolls/roll", roll: roll }
else
  json.roll nil
end
