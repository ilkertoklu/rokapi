class DeriveChoiceDifficultyLabels < ActiveRecord::Migration[8.1]
  def up
    remove_column :choices, :difficulty_label
  end

  def down
    add_column :choices, :difficulty_label, :string
    Choice.find_each { |choice| choice.update_column :difficulty_label, choice.difficulty_label }
    change_column_null :choices, :difficulty_label, false
  end
end
