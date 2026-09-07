class DelegateRollTargetsToChoices < ActiveRecord::Migration[8.1]
  def up
    remove_column :rolls, :modifier
    remove_column :rolls, :target
  end

  def down
    add_column :rolls, :modifier, :integer
    add_column :rolls, :target, :integer
    execute <<~SQL
      UPDATE rolls SET
        modifier = (SELECT modifier FROM choices WHERE choices.id = rolls.choice_id),
        target = (SELECT difficulty FROM choices WHERE choices.id = rolls.choice_id)
    SQL
    change_column_null :rolls, :modifier, false
    change_column_null :rolls, :target, false
  end
end
