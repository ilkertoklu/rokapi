class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.references :game_session, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.boolean :host, null: false, default: false
      t.boolean :ready, null: false, default: false

      t.timestamps
    end

    add_index :players, [ :game_session_id, :user_id ], unique: true
  end
end
