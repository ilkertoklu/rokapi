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
    assert_not user.verify_login_code(code), "a consumed code cannot be used again"
  end

  test "the initial leaves its casing to the page, which knows the language" do
    assert_equal "i", User.new(name: "ilker").initial
    assert_equal "R", User.new(name: "Robin").initial
  end

  test "profile_complete?" do
    assert users(:ilker).profile_complete?
    assert_not users(:incomplete).profile_complete?
  end

  test "complete_profile names the user and accepts the terms" do
    user = users(:incomplete)

    assert user.complete_profile(name: "Robin", terms: "1")

    assert user.reload.profile_complete?
    assert_equal "Robin", user.name
  end

  test "complete_profile records no acceptance the terms did not get" do
    user = users(:incomplete)

    assert_not user.complete_profile(name: "Robin", terms: "0")
    assert_not user.complete_profile(name: "Robin", terms: nil)

    assert_nil user.reload.terms_accepted_at
  end

  test "update_settings saves the name and holds a new email until it is confirmed" do
    user = users(:ilker)

    assert_enqueued_emails 1 do
      user.update_settings name: "Ilker T", email: " New@Ilker.test "
    end

    assert_equal "Ilker T", user.reload.name
    assert_equal "ilker@example.com", user.email
    assert_equal "new@ilker.test", user.unconfirmed_email
    assert user.email_change_pending?
  end

  test "saving the pending email again sends no second link" do
    user = users(:ilker)
    user.update_settings name: "Ilker", email: "new@ilker.test"

    assert_no_enqueued_emails do
      user.update_settings name: "Ilker T", email: "new@ilker.test"
    end
  end

  test "going back to the current email cancels the change" do
    user = users(:ilker)
    user.update_settings name: "Ilker", email: "new@ilker.test"

    assert_no_enqueued_emails do
      user.update_settings name: "Ilker", email: "ilker@example.com"
    end
    assert_not user.reload.email_change_pending?
  end

  test "confirm_email swaps in the new address" do
    user = users(:ilker)
    user.update_settings name: "Ilker", email: "new@ilker.test"

    user.confirm_email
    assert_equal "new@ilker.test", user.reload.email
    assert_nil user.unconfirmed_email
  end

  test "the confirmation token lasts 24 hours" do
    user = users(:ilker)
    user.update_settings name: "Ilker", email: "new@ilker.test"
    token = user.generate_token_for(:email_confirmation)

    travel 23.hours
    assert_equal user, User.find_by_token_for(:email_confirmation, token)

    travel 2.hours
    assert_nil User.find_by_token_for(:email_confirmation, token)
  end

  test "an email someone else holds cannot be requested" do
    assert_raises(ActiveRecord::RecordInvalid) do
      users(:ilker).update_settings name: "Ilker", email: users(:deniz).email
    end
  end
end
