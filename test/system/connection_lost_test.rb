require "application_system_test_case"

class ConnectionLostTest < ApplicationSystemTestCase
  setup do
    @game_session = game_sessions(:ilker_solo)
    @game_session.update! started_at: Time.current
    @game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host), state: :played,
      title: "The Old Inn", location: "Whitebend", narration: "Rain hammers the inn's shutters."
  end

  test "the game pauses while the stream is down and returns to the current scene" do
    sign_in_as users(:ilker)
    visit game_session_path(@game_session)
    assert_text "The Old Inn"
    assert_selector "turbo-cable-stream-source[connected]", visible: :all

    drop_connection
    assert_selector "dialog.connection[open]", text: "Connection lost", wait: 5
    assert_text "Your progress is saved"
    assert_link "Main menu", href: root_path

    @game_session.scenes.create! position: 2, active_player: players(:ilker_solo_host),
      title: "Blizzard Pass", location: "The pass", narration: "Snow swallows the road."

    click_on "Try again now"
    assert_no_selector "dialog.connection[open]", wait: 5
    assert_text "Blizzard Pass"
  end

  test "a passing hiccup does not interrupt the game" do
    sign_in_as users(:ilker)
    visit game_session_path(@game_session)
    assert_selector "turbo-cable-stream-source[connected]", visible: :all

    drop_connection
    reopen_connection
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    sleep 2.5
    assert_no_selector "dialog.connection[open]"
  end

  test "a page refresh from the narrator keeps the game running" do
    sign_in_as users(:ilker)
    visit game_session_path(@game_session)
    assert_selector "turbo-cable-stream-source[connected]", visible: :all

    @game_session.current_scene.update! title: "The Old Inn at Dusk"
    assert_text "The Old Inn at Dusk"
    sleep 2.5
    assert_no_selector "dialog.connection[open]"
  end

  test "the keyboard does not play behind the lost connection" do
    scene = @game_session.scenes.create! position: 2, active_player: players(:ilker_solo_host), state: :choosing,
      title: "Blizzard Pass", location: "The pass", narration: "Snow swallows the road."
    scene.choices.create! label: "Push on through the snow", stat: "constitution", target: 12

    sign_in_as users(:ilker)
    visit game_session_path(@game_session)
    find(".action-panel__handle").click
    assert_button "Push on through the snow"

    drop_connection
    assert_selector "dialog.connection[open]", wait: 5
    record_submissions
    send_keys "1"
    assert_empty submissions
    assert scene.reload.choosing?
  end

  private
    def record_submissions
      execute_script "window.submissions = []; addEventListener('submit', event => submissions.push(event.target.action), { capture: true })"
    end

    def submissions
      evaluate_script "window.submissions"
    end

    def drop_connection
      on_cable_connection "close({ allowReconnect: false })"
    end

    def reopen_connection
      on_cable_connection "open()"
    end

    def on_cable_connection(call)
      page.execute_script <<~JS
        import("@hotwired/turbo-rails").then(({ cable }) => cable.getConsumer()).then(consumer => consumer.connection.#{call})
      JS
    end
end
