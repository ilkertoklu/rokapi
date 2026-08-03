class AddChosenIndexToChoices < ActiveRecord::Migration[8.1]
  def change
    add_index :choices, :scene_id, unique: true, where: "chosen_at IS NOT NULL", name: "index_choices_on_chosen_scene"
  end
end
