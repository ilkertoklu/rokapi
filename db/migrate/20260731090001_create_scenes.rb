class CreateScenes < ActiveRecord::Migration[8.1]
  def change
    create_table :scenes do |t|
      t.references :game_session, null: false, foreign_key: true
      t.references :active_player, null: false, foreign_key: { to_table: :players }
      t.integer :position, null: false
      t.string :title
      t.string :location
      t.text :narration
      t.string :state, null: false, default: "narrating"
      t.boolean :finale, null: false, default: false

      t.timestamps
    end

    add_index :scenes, [ :game_session_id, :position ], unique: true
  end
end
