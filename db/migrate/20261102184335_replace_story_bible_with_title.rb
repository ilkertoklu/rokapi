class ReplaceStoryBibleWithTitle < ActiveRecord::Migration[8.1]
  def up
    add_column :game_sessions, :title, :string
    execute "UPDATE game_sessions SET title = json_extract(story_bible, '$.title')"
    remove_column :game_sessions, :story_bible
  end

  def down
    add_column :game_sessions, :story_bible, :json
    execute "UPDATE game_sessions SET story_bible = json_object('title', title) WHERE title IS NOT NULL"
    remove_column :game_sessions, :title
  end
end
