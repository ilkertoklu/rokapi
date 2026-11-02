class LetPlayersOutliveTheirAccounts < ActiveRecord::Migration[8.1]
  def change
    change_column_null :players, :user_id, true
  end
end
