class CreateAdventures < ActiveRecord::Migration[8.1]
  def change
    create_table :adventures do |t|
      t.string :title, null: false
      t.string :hook, null: false
      t.text :brief, null: false

      t.timestamps
    end

    add_index :adventures, :title, unique: true
  end
end
