class DropRedundantGameSessionIndexes < ActiveRecord::Migration[8.1]
  def change
    remove_index :players, :game_session_id, name: "index_players_on_game_session_id"
    remove_index :scenes, :game_session_id, name: "index_scenes_on_game_session_id"
  end
end
