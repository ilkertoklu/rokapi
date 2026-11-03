require "test_helper"

class SettingsFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    sign_in_as users(:ilker)
  end

  test "settings open from the profile" do
    get my_profile_path
    assert_select "a.menu-row[href=?]", my_settings_path, text: /Settings/

    get my_settings_path
    assert_select ".page-head h1", text: "Settings"
    assert_select "input[name='user[name]'][value=?]", "Ilker"
    assert_select "input[name='user[email]'][value=?]", "ilker@example.com"
  end

  test "changing the name saves at once" do
    assert_no_enqueued_emails do
      patch my_settings_path, params: { user: { name: "Ilker T", email: "ilker@example.com" } }
    end
    assert_redirected_to my_settings_path

    follow_redirect!
    assert_select ".flash--notice", text: "Saved."
    assert_equal "Ilker T", users(:ilker).reload.name
  end

  test "players on one network each get their own settings limit" do
    counting_rate_limits do
      5.times do
        patch my_settings_path, params: { user: { name: "Ilker", email: "ilker@example.com" } }
        assert_equal "Saved.", flash[:notice]
      end

      patch my_settings_path, params: { user: { name: "Ilker", email: "ilker@example.com" } }
      assert_match(/Too many changes/, flash[:alert])

      sign_in_as users(:deniz)
      patch my_settings_path, params: { user: { name: "Deniz", email: users(:deniz).email } }
      assert_equal "Saved.", flash[:notice]
    end
  end

  test "a blank name is refused and keeps what was typed" do
    patch my_settings_path, params: { user: { name: " ", email: "new@ilker.test" } }

    assert_response :unprocessable_entity
    assert_select ".flash--alert", text: /Name can't be blank/
    assert_select "input[name='user[email]'][value=?]", "new@ilker.test"
    assert_equal "Ilker", users(:ilker).reload.name
  end

  test "changing the email waits for the link sent to the new address" do
    perform_enqueued_jobs do
      patch my_settings_path, params: { user: { name: "Ilker T", email: "New@Ilker.test" } }
    end
    assert_redirected_to my_email_change_path
    assert_equal "Ilker T", users(:ilker).reload.name
    assert_equal "ilker@example.com", users(:ilker).email

    follow_redirect!
    assert_select ".sent__text strong", text: "new@ilker.test"
    assert_select ".addresses dt", text: "ilker@example.com"
    assert_select "a.btn[href=?]", my_settings_path, text: "Done"

    get my_settings_path
    assert_select "input[name='user[email]'][value=?]", "new@ilker.test"
    assert_select ".note strong", text: "ilker@example.com"

    mail = ActionMailer::Base.deliveries.sole
    assert_equal [ "new@ilker.test" ], mail.to
    patch mail.text_part.body.to_s[%r{http://example.com(/email_confirmations/\S+)}, 1]
    assert_redirected_to my_settings_path
    assert_equal "new@ilker.test", users(:ilker).reload.email
    assert_nil users(:ilker).unconfirmed_email

    follow_redirect!
    assert_select ".flash--notice", text: "Your email is now new@ilker.test."
  end

  test "opening the link asks before it changes anything" do
    link = request_email_change_to "new@ilker.test"

    2.times do
      get link
      assert_response :success
      assert_select ".sent__text strong", text: "new@ilker.test"
      assert_select "form[action=?] button.btn", link, text: "Confirm my email"
    end
    assert_equal "ilker@example.com", users(:ilker).reload.email
    assert_equal "new@ilker.test", users(:ilker).unconfirmed_email
  end

  test "the link confirms the email even when opened signed out" do
    link = request_email_change_to "new@ilker.test"
    delete session_path

    get link
    assert_response :success

    patch link
    assert_redirected_to new_login_code_path
    assert_equal "new@ilker.test", users(:ilker).reload.email
  end

  test "an expired link changes nothing" do
    link = request_email_change_to "new@ilker.test"

    travel 25.hours do
      get link
    end
    assert_redirected_to my_settings_path
    assert_match(/expired/, flash[:alert])
    assert_equal "ilker@example.com", users(:ilker).reload.email
  end

  test "a link is spent once the email is confirmed" do
    link = request_email_change_to "new@ilker.test"
    patch link

    get link
    assert_redirected_to my_settings_path
    assert_match(/expired/, flash[:alert])

    patch link
    assert_match(/expired/, flash[:alert])
  end

  test "a newer request voids the earlier link" do
    stale = request_email_change_to "first@ilker.test"
    request_email_change_to "second@ilker.test"

    patch stale
    assert_match(/expired/, flash[:alert])
    assert_equal "ilker@example.com", users(:ilker).reload.email
  end

  test "the old email keeps logging in until the new one is confirmed" do
    link = request_email_change_to "new@ilker.test"
    delete session_path

    post login_codes_path, params: { email: "ilker@example.com" }
    post session_path, params: { code: users(:ilker).login_codes.sole.code }
    assert_redirected_to root_url

    patch link
    delete session_path
    post login_codes_path, params: { email: "new@ilker.test" }
    post session_path, params: { code: users(:ilker).login_codes.sole.code }
    assert_redirected_to root_url
  end

  test "a confirmation that loses the address to another account drops the pending change" do
    link = request_email_change_to "new@ilker.test"
    users(:deniz).update_columns email: "new@ilker.test"

    patch link
    assert_redirected_to my_settings_path
    assert_equal "That email is already in use by another account.", flash[:alert]
    assert_equal "ilker@example.com", users(:ilker).reload.email
    assert_nil users(:ilker).unconfirmed_email
    assert_equal "new@ilker.test", users(:deniz).reload.email
  end

  test "an email that belongs to someone else is refused" do
    patch my_settings_path, params: { user: { name: "Ilker", email: users(:deniz).email } }

    assert_response :unprocessable_entity
    assert_select ".flash--alert", text: /Email has already been taken/
    assert_nil users(:ilker).reload.unconfirmed_email
  end

  test "settings as JSON" do
    get my_settings_path(format: :json)
    assert_equal({ "name" => "Ilker", "email" => "ilker@example.com", "unconfirmed_email" => nil }, response.parsed_body)

    patch my_settings_path(format: :json), params: { user: { name: "Ilker", email: "new@ilker.test" } }, as: :json
    assert_equal "new@ilker.test", response.parsed_body["unconfirmed_email"]

    patch my_settings_path(format: :json), params: { user: { name: "Ilker", email: "nope" } }, as: :json
    assert_response :unprocessable_entity
    assert response.parsed_body["unconfirmed_email"].present?
  end

  test "a JSON save without an email keeps the email" do
    patch my_settings_path(format: :json), params: { user: { name: "Ilker T" } }, as: :json

    assert_response :success
    assert_equal "Ilker T", users(:ilker).reload.name
    assert_equal "ilker@example.com", users(:ilker).email
    assert_nil users(:ilker).unconfirmed_email
  end

  test "a JSON save without a name is refused" do
    patch my_settings_path(format: :json), params: { user: { email: "ilker@example.com" } }, as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["name"].present?
    assert_equal "Ilker", users(:ilker).reload.name
  end

  private
    def request_email_change_to(email)
      perform_enqueued_jobs do
        patch my_settings_path, params: { user: { name: "Ilker", email: email } }
      end
      ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{http://example.com(/email_confirmations/\S+)}, 1]
    end
end
