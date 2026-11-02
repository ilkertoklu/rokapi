class AddPlanToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :plan, :string, null: false, default: "free"
  end
end
