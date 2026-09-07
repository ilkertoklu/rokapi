class RemoveModeFromGameSessions < ActiveRecord::Migration[8.1]
  def up
    remove_column :game_sessions, :mode
  end

  def down
    add_column :game_sessions, :mode, :string, null: false, default: "solo"
  end
end
