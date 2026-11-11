require "test_helper"

class LobbyFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @room = game_sessions(:ilker_room)
  end

  test "the lobby shows the room, the card and who is ready" do
    sign_in_as users(:deniz)
    ready_up players(:ilker_room_host)

    get game_session_path(@room)
    assert_response :success
    assert_select ".room-code__digits", text: "4821"
    assert_select ".lobby__quest h1", text: "A fog-bound fishing village"
    assert_select ".lobby__quest p", text: "A child went out at dusk and has not come back"
    assert_select ".lobby__quest p", text: "An old weather-reader who pleases no one"
    assert_select ".lobby__quest-meta", text: "5 players · ~15 min · balanced tone"
    assert_select ".lobby__players-head span", text: "2 / 5"
    assert_select ".lobby__players-head .visually-hidden", text: "2 of 5 players"

    assert_select ".lobby-player:nth-child(1).lobby-player--ready" do
      assert_select ".lobby-player__name", text: /Ilker\s+· HOST/
      assert_select ".lobby-player__line", text: "Human · Warrior"
      assert_select ".lobby-player__status", text: "Ready"
    end
    assert_select ".lobby-player:nth-child(2).lobby-player--you" do
      assert_select ".lobby-player__name", text: /Deniz\s+· YOU/
      assert_select ".lobby-player__line", text: "You have not created your character yet"
      assert_select ".lobby-player__status", text: "No character"
    end

    assert_select "a.btn[href=?]", new_game_session_character_path(@room), text: "Create your character"
    assert_select ".game", count: 0
  end

  test "others see a player who has not made a character yet as getting ready" do
    sign_in_as users(:ilker)

    get game_session_path(@room)
    assert_select ".lobby-player:nth-child(2) .lobby-player__status", text: "Getting ready"
    assert_select ".lobby-player:nth-child(2) .lobby-player__line", text: "choosing a character…"
  end

  test "a guest who just arrived is marked as just joined, the host never is" do
    room = GameSession.create!(creator: users(:ilker), card: "fishing_village missing_child weather_reader", max_players: GameSession::PARTY_SIZE)
    room.join users(:deniz)
    sign_in_as users(:sevval)
    room.join users(:sevval)

    get game_session_path(room)
    assert_select ".lobby-player:nth-child(1) .lobby-player__line", text: "choosing a character…"
    assert_select ".lobby-player:nth-child(2) .lobby-player__line", text: "just joined"
  end

  test "making a character in a room returns to the lobby without starting" do
    sign_in_as users(:deniz)

    assert_no_enqueued_jobs only: Scene::NarrateJob do
      post game_session_character_path(@room), params: { character: warrior }
    end
    assert_redirected_to game_session_path(@room)

    follow_redirect!
    assert_select ".lobby-player--you.lobby-player--ready"
    assert_select ".lobby__note", text: "Only Ilker can start the adventure"
    assert_select "form[action=?]", game_session_start_path(@room), count: 0
    assert_not @room.reload.started?
  end

  test "the host starts once everyone is ready" do
    sign_in_as users(:ilker)
    ready_up players(:ilker_room_host)

    get game_session_path(@room)
    assert_select ".lobby__note", text: "You can start once everyone is ready"
    assert_select "form[action=?] button[disabled]", game_session_start_path(@room)

    ready_up players(:deniz_room_guest)
    get game_session_path(@room)
    assert_select ".lobby__note", text: "Everyone is ready · only you can start"
    assert_select "form[action=?] button:not([disabled])", game_session_start_path(@room), text: "Start the adventure"

    assert_enqueued_with job: Scene::NarrateJob do
      post game_session_start_path(@room)
    end
    assert_redirected_to game_session_path(@room)
    assert @room.reload.started?
    assert_equal players(:ilker_room_host), @room.current_scene.active_player

    follow_redirect!
    assert_select ".lobby", count: 0
    assert_select ".game"
  end

  test "only the host can start" do
    ready_up players(:ilker_room_host)
    ready_up players(:deniz_room_guest)
    sign_in_as users(:deniz)

    post game_session_start_path(@room)
    assert_response :forbidden

    post game_session_start_path(@room, format: :json)
    assert_response :forbidden
    assert_not @room.reload.started?
  end

  test "the host cannot start before everyone is ready" do
    ready_up players(:ilker_room_host)
    sign_in_as users(:ilker)

    post game_session_start_path(@room)
    assert_redirected_to game_session_path(@room)
    assert_equal "The adventure starts once everyone is ready.", flash[:alert]
    assert_not @room.reload.started?
  end

  test "the lobby as JSON" do
    ready_up players(:ilker_room_host)
    sign_in_as users(:ilker)

    get game_session_path(@room, format: :json)
    game = response.parsed_body
    assert game["lobby"]
    assert game["host"]
    assert_equal "4821", game["code"]
    assert_not game["everyone_ready"]
    assert_equal [ [ "Ilker", true, true, true ], [ "Deniz", false, false, false ] ],
      game["players"].map { [ it["name"], it["host"], it["you"], it["ready"] ] }

    ready_up players(:deniz_room_guest)
    post game_session_start_path(@room, format: :json)
    assert_response :created

    get game_session_path(@room, format: :json)
    assert_not response.parsed_body["lobby"]
  end

  test "a solo game never shows a lobby" do
    sign_in_as users(:ilker)

    get game_session_path(game_sessions(:ilker_without_character))
    assert_redirected_to new_game_session_character_path(game_sessions(:ilker_without_character))
  end

  private
    def warrior
      { race: "human", klass: "warrior", background: "soldier",
        stats: Character::Klass.fetch("warrior").base_stats.merge("strength" => 16, "constitution" => 15, "charisma" => 14) }
    end

    def ready_up(player)
      player.create_character! warrior
    end
end
