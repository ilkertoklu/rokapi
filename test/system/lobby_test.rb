require "application_system_test_case"

class LobbyTest < ApplicationSystemTestCase
  test "copying the room code" do
    sign_in_as users(:ilker)
    visit game_session_path(game_sessions(:ilker_room))
    assert_text "4821"

    click_on "Copy the room code"
    assert_selector ".room-code__copied", text: "Copied"
  end

  test "the copy button stays away where the browser cannot copy, even as players join" do
    sign_in_as users(:ilker)
    visit game_session_path(game_sessions(:ilker_room))
    assert_selector "turbo-cable-stream-source[connected]", visible: :all

    execute_script <<~JS
      Object.defineProperty(Navigator.prototype, "clipboard", { get: () => undefined, configurable: true })
      Object.defineProperty(Navigator.prototype, "share", { value: undefined, configurable: true })
      Turbo.visit(location.href)
    JS
    assert_no_button "Copy the room code"
    assert_selector "turbo-cable-stream-source[connected]", visible: :all

    game_sessions(:ilker_room).players.create! user: users(:sevval)
    assert_text "Sevval"
    assert_no_button "Copy the room code"
  end
end
