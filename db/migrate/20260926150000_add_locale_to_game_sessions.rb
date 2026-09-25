class AddLocaleToGameSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :locale, :string, null: false, default: "en"
  end
end
