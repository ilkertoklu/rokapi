class AddEffectsToScenes < ActiveRecord::Migration[8.1]
  def change
    add_column :scenes, :effects, :json
  end
end
