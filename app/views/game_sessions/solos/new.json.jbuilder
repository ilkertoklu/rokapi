json.quests GameSession::Quest.all do |quest|
  json.(quest, :key, :title, :hook)
end

json.tones GameSession::Tone.all do |tone|
  json.(tone, :key, :label)
end

json.lengths GameSession::Length.all do |length|
  json.(length, :key, :label, :scenes)
end
