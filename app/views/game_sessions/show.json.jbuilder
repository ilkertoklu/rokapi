json.(@game_session, :id, :title, :surprise, :tone, :length, :locale, :scene_budget, :outcome)
json.started @game_session.started?

unless @game_session.surprise?
  json.card do
    json.place @game_session.card.place.text
    json.trouble @game_session.card.trouble.text
    json.figure @game_session.card.figure.text
  end
end

json.finished @game_session.finished?
json.your_turn @game_session.current_scene&.active_player == @player
json.multiplayer @game_session.multiplayer?
json.rematch_id @game_session.rematch&.id
json.(@game_session, :code, :max_players)
json.lobby @game_session.lobby?
json.host @player == @game_session.host
json.everyone_ready @game_session.everyone_ready?

json.players @game_session.players.in_join_order.includes(:user, :character) do |member|
  json.name member.name
  json.host member == @game_session.host
  json.you member == @player
  json.ready member.ready?
  json.summary member.character&.summary
end
json.cost @game_session.cost.total&.to_f

if @character
  json.character { json.partial! "characters/character", character: @character }
else
  json.character nil
end

json.scenes @game_session.scenes.chronological, partial: "scenes/scene", as: :scene

survivors = @game_session.survivors
json.party @game_session.party do |player|
  json.name player.name
  json.summary player.character&.summary
  json.you player == @player
  json.alive survivors.include?(player)
end
