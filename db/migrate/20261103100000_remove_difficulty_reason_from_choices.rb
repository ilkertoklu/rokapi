class RemoveDifficultyReasonFromChoices < ActiveRecord::Migration[8.1]
  def change
    remove_column :choices, :difficulty_reason, :string
  end
end
