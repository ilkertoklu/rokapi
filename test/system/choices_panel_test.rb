require "application_system_test_case"

class ChoicesPanelTest < ApplicationSystemTestCase
  setup do
    @game_session = game_sessions(:ilker_solo)
    @game_session.update! started_at: Time.current
    @scene = @game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host), state: :choosing,
      title: "The Old Inn", location: "Whitebend", narration: "Rain hammers the inn's shutters."
    @scene.choices.create! label: "Force the cellar door", stat: "strength", modifier: 3, target: 12

    sign_in_as users(:ilker)
  end

  teardown do
    page.current_window.resize_to 430, 932
  end

  test "a refresh leaves the opened choices open" do
    visit game_session_path(@game_session)
    find(".action-panel__handle").click
    assert_button "Force the cellar door"

    @scene.update! title: "The Old Inn at Dusk"
    assert_text "The Old Inn at Dusk"
    assert_button "Force the cellar door"
  end

  test "a refresh leaves the pinned choices pinned" do
    page.current_window.resize_to 820, 1180
    visit game_session_path(@game_session)
    assert_selector ".action-panel[open] .action-panel__handle[tabindex='-1']"

    @scene.update! title: "The Old Inn at Dusk"
    assert_text "The Old Inn at Dusk"
    assert_selector ".action-panel[open] .action-panel__handle[tabindex='-1']"
  end
end
