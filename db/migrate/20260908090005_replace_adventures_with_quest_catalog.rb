class ReplaceAdventuresWithQuestCatalog < ActiveRecord::Migration[8.1]
  KEYS_BY_TITLE = { "Kayıp Kervan" => "lost_caravan", "Gölün Sırrı" => "sunken_village" }.freeze

  def up
    add_column :game_sessions, :quest, :string
    KEYS_BY_TITLE.each do |title, key|
      execute "UPDATE game_sessions SET quest = #{quote(key)} WHERE adventure_id = (SELECT id FROM adventures WHERE title = #{quote(title)})"
    end
    remove_reference :game_sessions, :adventure, foreign_key: true
    drop_table :adventures
  end

  def down
    create_table :adventures do |t|
      t.string :title, null: false
      t.string :hook, null: false
      t.text :brief, null: false
      t.timestamps
      t.index :title, unique: true
    end
    KEYS_BY_TITLE.each_key do |title|
      execute "INSERT INTO adventures (title, hook, brief, created_at, updated_at) VALUES (#{quote(title)}, '', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    end
    add_reference :game_sessions, :adventure, foreign_key: true
    KEYS_BY_TITLE.each do |title, key|
      execute "UPDATE game_sessions SET adventure_id = (SELECT id FROM adventures WHERE title = #{quote(title)}) WHERE quest = #{quote(key)}"
    end
    remove_column :game_sessions, :quest
  end
end
