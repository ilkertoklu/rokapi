class ReplaceStoryOutlineWithStoryBible < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :story_bible, :json
    remove_column :game_sessions, :story_outline, :text
    remove_column :game_sessions, :context_summary, :text
    remove_column :game_sessions, :context_summary_position, :integer, default: 0, null: false
  end
end
