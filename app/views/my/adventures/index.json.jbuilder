json.array! @adventures do |adventure|
  json.(adventure, :id, :title, :outcome, :locale, :ended_at)
  json.multiplayer adventure.multiplayer?
  json.hero adventure_hero(adventure)&.summary
end
