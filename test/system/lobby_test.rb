require "application_system_test_case"

class LobbyTest < ApplicationSystemTestCase
  test "copying the room code" do
    sign_in_as users(:ilker)
    visit game_session_path(game_sessions(:ilker_room))
    assert_text "4821"

    click_on "Copy the room code"
    assert_selector ".room-code__copied", text: "Copied"
  end
end
