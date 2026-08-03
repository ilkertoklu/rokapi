class AddContextSummaryPositionToGameSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :context_summary_position, :integer, null: false, default: 0
  end
end
