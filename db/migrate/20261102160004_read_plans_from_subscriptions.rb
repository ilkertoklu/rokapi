class ReadPlansFromSubscriptions < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :plan, :string, null: false, default: "free"
  end
end
