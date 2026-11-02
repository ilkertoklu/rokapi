class AddRoomCodeToGameSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :code, :string
    add_column :game_sessions, :max_players, :integer, null: false, default: 1
    add_index :game_sessions, :code, unique: true, where: "started_at IS NULL"
  end
end
