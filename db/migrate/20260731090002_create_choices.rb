class CreateChoices < ActiveRecord::Migration[8.1]
  def change
    create_table :choices do |t|
      t.references :scene, null: false, foreign_key: true
      t.string :label, null: false
      t.string :stat, null: false
      t.integer :modifier, null: false, default: 0
      t.integer :difficulty, null: false
      t.string :difficulty_label, null: false
      t.string :difficulty_reason
      t.datetime :chosen_at

      t.timestamps
    end
  end
end
