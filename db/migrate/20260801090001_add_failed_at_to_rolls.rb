class AddFailedAtToRolls < ActiveRecord::Migration[8.1]
  def change
    add_column :rolls, :failed_at, :datetime
  end
end
