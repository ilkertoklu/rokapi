require "test_helper"

Capybara.enable_aria_label = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 430, 932 ]

  private
    def sign_in_as(user)
      visit new_login_code_path
      fill_in "Email", with: user.email
      click_on "Send code"
      assert_text "We sent a one-time"
      fill_in "code", with: user.login_codes.sole.code
      click_on "Verify"
      assert_text "Roll the dice"
    end
end
