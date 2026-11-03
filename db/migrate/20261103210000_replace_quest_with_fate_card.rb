class ReplaceQuestWithFateCard < ActiveRecord::Migration[8.1]
  def up
    add_column :game_sessions, :place, :string
    add_column :game_sessions, :trouble, :string
    add_column :game_sessions, :figure, :string
    add_column :game_sessions, :twist, :string
    add_column :game_sessions, :surprise, :boolean, default: false, null: false

    execute <<~SQL
      UPDATE game_sessions SET
        title = COALESCE(NULLIF(title, ''), CASE quest
          WHEN 'lost_caravan' THEN CASE locale WHEN 'tr' THEN 'Kayıp Kervan' ELSE 'The Lost Caravan' END
          WHEN 'sunken_village' THEN CASE locale WHEN 'tr' THEN 'Gölün Sırrı' ELSE 'The Lake''s Secret' END
        END),
        place = 'fishing_village', trouble = 'missing_child', figure = 'weather_reader', twist = 'asker_is_cause',
        surprise = (quest IS NULL)
    SQL

    remove_column :game_sessions, :quest
  end

  def down
    add_column :game_sessions, :quest, :string
    remove_column :game_sessions, :place
    remove_column :game_sessions, :trouble
    remove_column :game_sessions, :figure
    remove_column :game_sessions, :twist
    remove_column :game_sessions, :surprise
  end
end
