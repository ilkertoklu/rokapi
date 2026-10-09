json.(character, :race, :klass, :background, :summary, :hp, :max_hp, :stats)
json.name character.user.name

json.items character.items.carried.order(:id) do |item|
  json.(item, :id, :name, :kind, :description, :hp_effect, :uses_left, :summary)
  json.usable item.usable?
end

json.statuses character.status_effects.order(:id) do |status|
  json.(status, :name, :modifier, :turns_left, :expires_when, :summary)
end
