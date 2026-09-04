class RetireFinishedGameSessionState < ActiveRecord::Migration[8.1]
  def up
    GameSession.where(state: "finished").update_all(state: "playing")
  end

  def down
    GameSession.where.not(ended_at: nil).update_all(state: "finished")
  end
end
