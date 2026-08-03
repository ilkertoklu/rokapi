class AddContextSummaryToGameSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :context_summary, :text
  end
end
