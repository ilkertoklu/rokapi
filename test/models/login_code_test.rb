require "test_helper"

class LoginCodeTest < ActiveSupport::TestCase
  setup do
    @user = users(:ilker)
  end

  test "generates a six digit code and stores it encrypted" do
    login_code = @user.login_codes.create!

    assert_match(/\A\d{6}\z/, login_code.code)
    assert_not_equal login_code.code, login_code.ciphertext_for(:code)
  end

  test "expires" do
    login_code = @user.login_codes.create!

    travel LoginCode::EXPIRATION_TIME + 1.minute do
      assert_empty @user.login_codes.active
      assert_not @user.verify_login_code(login_code.code)
    end
  end

  test "wrong attempts count up and exhaust the code" do
    login_code = @user.login_codes.create!

    (LoginCode::MAX_ATTEMPTS - 1).times { assert_not @user.verify_login_code("000000") }
    assert @user.verify_login_code(login_code.code), "son denemeden önce doğru kod hâlâ geçerli"

    login_code = @user.login_codes.create!
    LoginCode::MAX_ATTEMPTS.times { @user.verify_login_code("000000") }
    assert_not @user.verify_login_code(login_code.code), "deneme hakkı bitince doğru kod bile geçmez"
  end

  test "cleanup deletes stale codes" do
    @user.login_codes.create!

    travel LoginCode::EXPIRATION_TIME + 1.minute do
      assert_difference -> { LoginCode.count }, -1 do
        LoginCode.cleanup
      end
    end
  end
end
