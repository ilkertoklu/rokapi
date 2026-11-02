require "test_helper"

class EmailConfirmationMailerTest < ActionMailer::TestCase
  test "the link goes to the new address" do
    user = users(:ilker)
    user.update! unconfirmed_email: "new@ilker.test"
    email = EmailConfirmationMailer.with(user: user).confirmation

    assert_equal [ "new@ilker.test" ], email.to
    assert_equal "Confirm your new Rokapi email", email.subject
    assert_match %r{http://example.com/email_confirmations/\S+}, email.text_part.body.to_s
    assert_match %r{href="http://example.com/email_confirmations/[^"]+"}, email.html_part.body.to_s
  end
end
