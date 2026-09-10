require "application_system_test_case"

class SoloSetupTest < ApplicationSystemTestCase
  test "logging in and spending the character's free points" do
    visit new_login_code_path
    fill_in "Email", with: users(:sevval).email
    click_on "Send code"
    assert_text "We sent a one-time"

    fill_in "code", with: LoginCode.last.code
    click_on "Verify"
    assert_text "Roll the dice"

    click_on "Start a new adventure"
    click_on "Solo"
    click_on "Create your character"

    choose "Mage", allow_label_click: true
    assert_field "character[stats][intelligence]", with: "15"
    assert_button "I'm ready · 6 points left", disabled: true

    3.times { increment "intelligence" }
    3.times { increment "wisdom" }
    assert_field "character[stats][intelligence]", with: "18"
    assert_field "character[stats][wisdom]", with: "17"

    click_on "I'm ready"
    assert_text "The narrator is getting ready"

    character = users(:sevval).game_sessions.sole.player_for(users(:sevval)).character
    assert_equal "mage", character.klass
    assert_equal 18, character.stats["intelligence"]
  end

  private
    def increment(stat)
      find("button[data-action='stats#increment'][data-stats-key-param='#{stat}']").click
    end
end
