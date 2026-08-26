class CreateStatusEffects < ActiveRecord::Migration[8.1]
  def change
    create_table :status_effects do |t|
      t.references :character, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.integer :modifier, null: false
      t.integer :turns_left
      t.string :expires_when

      t.timestamps

      t.index [ :character_id, :name ], unique: true
      t.check_constraint "turns_left IS NOT NULL OR expires_when IS NOT NULL", name: "status_effects_have_a_duration"
    end
  end
end
