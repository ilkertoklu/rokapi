class AddStoryOutlineToGameSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :story_outline, :text
  end
end
