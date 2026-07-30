require "test_helper"

class UserTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "normalizes email" do
    user = User.create!(email: "  Deneme@Posta.COM ")
    assert_equal "deneme@posta.com", user.email
  end

  test "rejects invalid email" do
    assert_not User.new(email: "gecersiz").valid?
    assert_not User.new(email: "").valid?
  end

  test "duplicate email is stopped by the database" do
    assert_raises ActiveRecord::RecordNotUnique do
      2.times { User.insert_all!([ { email: "ayni@posta.com", created_at: Time.current, updated_at: Time.current } ]) }
    end
  end

  test "send_login_code creates a fresh code and enqueues the mailer" do
    user = users(:ilker)
    stale = user.send_login_code

    assert_enqueued_emails 1 do
      fresh = user.send_login_code
      assert_not_equal stale.code, fresh.code
    end

    assert_equal 1, user.login_codes.count
  end

  test "verify_login_code accepts the current code once" do
    user = users(:ilker)
    code = user.send_login_code.code

    assert user.verify_login_code(code)
    assert_not user.verify_login_code(code), "kod tüketildikten sonra tekrar kullanılamaz"
  end

  test "profile_complete?" do
    assert users(:ilker).profile_complete?
    assert_not users(:incomplete).profile_complete?
  end

  test "complete_profile! requires a name" do
    user = users(:incomplete)

    assert_raises(ActiveRecord::RecordInvalid) { user.complete_profile!(name: "") }

    user.complete_profile!(name: "Yeni")
    assert user.profile_complete?
  end
end
