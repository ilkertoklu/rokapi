class ReplaceFailedSceneStateWithFailedAt < ActiveRecord::Migration[8.1]
  def up
    add_column :scenes, :failed_at, :datetime
    Scene.where(state: "failed").update_all(state: "narrating", failed_at: Time.current)
  end

  def down
    Scene.where.not(failed_at: nil).update_all(state: "failed")
    remove_column :scenes, :failed_at
  end
end
