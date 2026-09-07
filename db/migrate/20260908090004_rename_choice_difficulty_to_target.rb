class RenameChoiceDifficultyToTarget < ActiveRecord::Migration[8.1]
  def change
    rename_column :choices, :difficulty, :target
  end
end
