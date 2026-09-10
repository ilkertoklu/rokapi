require "test_helper"

class LoginCodeMailerTest < ActionMailer::TestCase
  test "code email carries the code in subject and body" do
    login_code = users(:ilker).login_codes.create!
    email = LoginCodeMailer.with(login_code: login_code).code

    assert_equal [ "ilker@example.com" ], email.to
    assert_equal "Your Rokapi code: #{login_code.code}", email.subject
    assert_match login_code.code, email.text_part.body.to_s
    assert_match login_code.code, email.html_part.body.to_s
  end
end
