json.(@game_session, :id, :title, :quest, :tone, :length, :locale, :scene_budget, :outcome)
json.started @game_session.started?
json.finished @game_session.finished?
json.your_turn @game_session.current_scene&.active_player == @player
json.cost_in_microdollars @game_session.llm_calls.sum(:cost_in_microdollars)

if @character
  json.character { json.partial! "characters/character", character: @character }
else
  json.character nil
end

json.scenes @game_session.scenes.chronological, partial: "scenes/scene", as: :scene
