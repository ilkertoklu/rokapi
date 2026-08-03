class AddAcknowledgedAtToRolls < ActiveRecord::Migration[8.1]
  def change
    add_column :rolls, :acknowledged_at, :datetime
  end
end
