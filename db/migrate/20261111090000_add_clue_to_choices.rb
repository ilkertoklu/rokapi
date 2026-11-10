class AddClueToChoices < ActiveRecord::Migration[8.1]
  def change
    add_column :choices, :clue, :boolean, default: false, null: false
  end
end
