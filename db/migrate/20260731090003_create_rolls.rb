class CreateRolls < ActiveRecord::Migration[8.1]
  def change
    create_table :rolls do |t|
      t.references :choice, null: false, foreign_key: true, index: { unique: true }
      t.references :player, null: false, foreign_key: true
      t.integer :value, null: false
      t.integer :modifier, null: false
      t.integer :target, null: false
      t.boolean :success, null: false
      t.text :resolution
      t.json :effects

      t.timestamps
    end
  end
end
