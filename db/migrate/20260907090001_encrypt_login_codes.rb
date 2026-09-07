class EncryptLoginCodes < ActiveRecord::Migration[8.1]
  def up
    LoginCode.delete_all
    rename_column :login_codes, :code_digest, :code
  end

  def down
    LoginCode.delete_all
    rename_column :login_codes, :code, :code_digest
  end
end
