class RenameFailedAtToStalledAt < ActiveRecord::Migration[8.1]
  def change
    rename_column :scenes, :failed_at, :stalled_at
    rename_column :rolls, :failed_at, :stalled_at
  end
end
