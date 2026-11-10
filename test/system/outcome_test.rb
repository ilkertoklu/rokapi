require "application_system_test_case"

class OutcomeTest < ApplicationSystemTestCase
  setup do
    @game_session = game_sessions(:ilker_solo)
    @game_session.update! started_at: Time.current
    scene = @game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host), state: :played,
      title: "The Old Inn", location: "Whitebend", narration: "Rain hammers the inn's shutters."
    choice = scene.choices.create! label: "Force the cellar door", stat: "strength", modifier: 3, target: 12, chosen_at: Time.current
    choice.create_roll!(player: players(:ilker_solo_host), value: 15)
      .resolve resolution: ([ "The door gives with a crack that wakes the whole inn." ] * 12).join("\n\n"), effects: {}
  end

  teardown do
    page.current_window.resize_to 430, 932
  end

  test "a long outcome on a small phone keeps the die in view" do
    sign_in_as users(:ilker)
    page.current_window.resize_to 375, 667
    visit game_session_path(@game_session)

    assert_selector ".outcome__resolution", text: "wakes the whole inn"
    assert_operator evaluate_script("document.querySelector('.d20').getBoundingClientRect().top"), :>=, 0
    assert_button "Continue"
  end
end
