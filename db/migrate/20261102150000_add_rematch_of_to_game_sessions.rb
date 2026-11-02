class AddRematchOfToGameSessions < ActiveRecord::Migration[8.1]
  def change
    add_reference :game_sessions, :rematch_of, index: { unique: true },
      foreign_key: { to_table: :game_sessions, on_delete: :nullify }
  end
end
