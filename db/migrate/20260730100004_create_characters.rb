class CreateCharacters < ActiveRecord::Migration[8.1]
  def change
    create_table :characters do |t|
      t.references :player, null: false, foreign_key: true, index: { unique: true }
      t.string :race, null: false
      t.string :klass, null: false
      t.string :background, null: false
      t.json :stats, null: false
      t.integer :hp, null: false
      t.integer :max_hp, null: false

      t.timestamps
    end
  end
end
