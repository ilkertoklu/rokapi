class RemoveRoomCodeFromGameSessions < ActiveRecord::Migration[8.1]
  def change
    remove_index :game_sessions, :room_code, name: "index_game_sessions_on_room_code",
      unique: true, where: "state = 'lobby' AND room_code IS NOT NULL"
    remove_column :game_sessions, :room_code, :string
  end
end
