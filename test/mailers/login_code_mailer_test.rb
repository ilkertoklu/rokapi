require "test_helper"

class LoginCodeMailerTest < ActionMailer::TestCase
  test "code email carries the code in subject and body" do
    email = LoginCodeMailer.with(user: users(:ilker), code: "123456").code

    assert_equal [ "ilker@example.com" ], email.to
    assert_equal "Rokapi kodun: 123456", email.subject
    assert_match "123456", email.text_part.body.to_s
    assert_match "123456", email.html_part.body.to_s
  end
end
