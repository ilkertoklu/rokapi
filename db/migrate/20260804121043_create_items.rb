class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.references :character, null: false, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false
      t.string :description
      t.integer :hp_effect, null: false, default: 0
      t.integer :uses_left
      t.datetime :used_at

      t.timestamps
    end
  end
end
