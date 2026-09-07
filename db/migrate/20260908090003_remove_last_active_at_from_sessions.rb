class RemoveLastActiveAtFromSessions < ActiveRecord::Migration[8.1]
  def up
    remove_column :sessions, :last_active_at
  end

  def down
    add_column :sessions, :last_active_at, :datetime
    execute "UPDATE sessions SET last_active_at = updated_at"
    change_column_null :sessions, :last_active_at, false
  end
end
