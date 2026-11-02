json.(@game_session, :id, :title, :quest, :tone, :length, :locale, :scene_budget, :outcome)
json.started @game_session.started?
json.finished @game_session.finished?
json.your_turn @game_session.current_scene&.active_player == @player
json.multiplayer @game_session.multiplayer?
json.(@game_session, :code, :max_players)
json.lobby @game_session.lobby?
json.host @player == @game_session.host
json.everyone_ready @game_session.everyone_ready?

json.players @game_session.players.in_join_order.includes(:user, :character) do |member|
  json.name member.user.name
  json.host member == @game_session.host
  json.you member == @player
  json.ready member.ready?
  json.summary member.character&.summary
end
json.cost_in_microdollars @game_session.llm_calls.sum(:cost_in_microdollars)

if @character
  json.character { json.partial! "characters/character", character: @character }
else
  json.character nil
end

json.scenes @game_session.scenes.chronological, partial: "scenes/scene", as: :scene

json.party @game_session.party do |player|
  json.name player.name
  json.summary player.character&.summary
  json.you player == @player
end
