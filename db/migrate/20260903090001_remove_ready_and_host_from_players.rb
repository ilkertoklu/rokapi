class RemoveReadyAndHostFromPlayers < ActiveRecord::Migration[8.1]
  def change
    remove_column :players, :ready, :boolean, null: false, default: false
    remove_column :players, :host, :boolean, null: false, default: false
  end
end
