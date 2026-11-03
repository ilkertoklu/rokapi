json.cards @cards do |card|
  json.key card.key
  json.place card.place.text
  json.trouble card.trouble.text
  json.figure card.figure.text
end

json.tones GameSession::Tone.all do |tone|
  json.(tone, :key, :label)
end

json.lengths GameSession::Length.all do |length|
  json.(length, :key, :label, :scenes)
end
