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

  test "a swipe up on the handle opens the choices and a swipe down closes them" do
    visit game_session_path(@game_session)
    assert_no_button "Force the cellar door"

    swipe ".action-panel__handle", down: -200
    assert_button "Force the cellar door"

    swipe ".action-panel__handle", down: 50
    assert_no_button "Force the cellar door"
  end

  test "a tap on the handle still opens and closes the choices" do
    visit game_session_path(@game_session)

    find(".action-panel__handle").click
    assert_button "Force the cellar door"

    find(".action-panel__handle").click
    assert_no_button "Force the cellar door"
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

  test "turning the phone sideways pins the choices and turning it back hands the handle back" do
    visit game_session_path(@game_session)
    assert_no_button "Force the cellar door"

    page.current_window.resize_to 844, 390
    assert_selector ".action-panel[open] .action-panel__handle[tabindex='-1']"

    page.current_window.resize_to 390, 844
    assert_button "Force the cellar door"
    assert_selector ".action-panel__handle:not([tabindex])"
  end
end
