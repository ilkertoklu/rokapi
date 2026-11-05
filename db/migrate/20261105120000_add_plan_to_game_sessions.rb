class AddPlanToGameSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :plan, :text
  end
end
