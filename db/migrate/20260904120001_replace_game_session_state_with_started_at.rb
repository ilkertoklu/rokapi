class ReplaceGameSessionStateWithStartedAt < ActiveRecord::Migration[8.1]
  def up
    add_column :game_sessions, :started_at, :datetime
    GameSession.where(state: "playing").update_all("started_at = created_at")
    remove_column :game_sessions, :state
  end

  def down
    add_column :game_sessions, :state, :string, null: false, default: "lobby"
    GameSession.where.not(started_at: nil).update_all(state: "playing")
    remove_column :game_sessions, :started_at
  end
end
