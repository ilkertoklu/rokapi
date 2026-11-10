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

    def swipe(selector, down:, steps: 8, step_duration: 0.05)
      assert_panels_at_rest
      action = page.driver.browser.action
      action.add_pointer_input(:touch, "finger")
      action.move_to(find(selector).native, device: "finger", duration: 0).pointer_down(device: "finger")
      steps.times { action.move_by(0, down / steps, device: "finger", duration: step_duration) }
      action.pointer_up(device: "finger").perform
      action.release_actions
    end

    def assert_panels_at_rest
      page.document.synchronize do
        sliding = evaluate_script("document.getAnimations().some(animation => !(animation instanceof CSSAnimation))")
        raise Capybara::ExpectationNotMet, "A panel is still sliding" if sliding
      end
    end
end
