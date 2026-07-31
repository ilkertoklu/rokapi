class CreateGameSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :game_sessions do |t|
      t.references :adventure, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.string :mode, null: false
      t.string :tone, null: false
      t.string :length, null: false
      t.string :state, null: false, default: "lobby"
      t.string :room_code
      t.string :outcome
      t.datetime :ended_at

      t.timestamps
    end

    add_index :game_sessions, :room_code, unique: true,
      where: "state = 'lobby' AND room_code IS NOT NULL"
  end
end
