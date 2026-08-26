class AddStatusModifierToRolls < ActiveRecord::Migration[8.1]
  def change
    add_column :rolls, :status_modifier, :integer, null: false, default: 0
  end
end
