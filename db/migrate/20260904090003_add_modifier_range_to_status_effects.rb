class AddModifierRangeToStatusEffects < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :status_effects, "modifier BETWEEN -2 AND 2", name: "status_effects_modifier_within_dice_range"
  end
end
