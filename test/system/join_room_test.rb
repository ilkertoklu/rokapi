require "application_system_test_case"

class JoinRoomTest < ApplicationSystemTestCase
  test "fixing a mistyped code and joining" do
    room = game_sessions(:ilker_room)

    visit new_login_code_path
    fill_in "Email", with: users(:sevval).email
    click_on "Send code"
    assert_text "We sent a one-time"
    fill_in "code", with: users(:sevval).login_codes.sole.code
    click_on "Verify"

    click_on "Join with a code"
    fill_in "Room code", with: "0000"
    click_on "Join"
    assert_text "Room not found"
    assert_no_button "Join"

    click_on "Change the code"
    assert_no_text "Room not found"
    assert_button "Join · 4 digits left", disabled: true

    fill_in "Room code", with: room.code
    click_on "Join"
    assert_text "Create your character"
    assert_includes room.players.reload.map(&:user), users(:sevval)
  end
end
