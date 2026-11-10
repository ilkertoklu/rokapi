require "test_helper"

class RoomFlowTest < ActionDispatch::IntegrationTest
  test "home and the mode picker lead to joining and to a room" do
    sign_in_as users(:ilker)

    get root_path
    assert_select "a.btn[href=?]", new_game_sessions_join_path, text: "Join with a code"

    get new_game_session_path
    assert_select "a.pick[href=?]", new_game_sessions_multi_path, text: /Multiplayer/
    assert_select ".pick--disabled", count: 0
  end

  test "creating a room sends the host to it with a fresh code" do
    sign_in_as users(:sevval)

    get new_game_sessions_multi_path
    assert_select "button[type=submit]", text: /Create room/
    assert_select ".segment small", text: "~60 min"

    post game_sessions_multi_path, params: { game_session: { card: "mining_town dry_well indebted_smith", tone: "dark", length: "short" } }

    room = users(:sevval).game_sessions.sole
    assert_redirected_to game_session_path(room)
    assert room.multiplayer?
    assert_match(/\A\d{4}\z/, room.code)
    assert_equal GameSession::PARTY_SIZE, room.max_players
    assert_equal [ %w[ mining_town dry_well indebted_smith ], "dark", "short" ], [ room.card.keys, room.tone, room.length ]
    assert_equal room.host, room.players.sole
    assert_not room.started?
  end

  test "friends on one network each get their own room limit" do
    room = { game_session: { card: "mining_town dry_well indebted_smith", tone: "dark", length: "short" } }

    counting_rate_limits do
      sign_in_as users(:sevval)
      10.times { post game_sessions_multi_path, params: room }
      assert_no_difference -> { GameSession.count } do
        post game_sessions_multi_path, params: room
      end
      assert_match(/Too many rooms created/, flash[:alert])

      sign_in_as users(:deniz)
      assert_difference -> { GameSession.count } do
        post game_sessions_multi_path, params: room
      end
    end
  end

  test "joining a room by its code" do
    room = game_sessions(:ilker_room)
    sign_in_as users(:sevval)

    get new_game_sessions_join_path
    assert_select "input[name=code][maxlength=4][inputmode=numeric]"
    assert_select ".rejection", count: 0

    post game_sessions_join_path, params: { code: room.code }
    assert_redirected_to game_session_path(room)
    assert_includes room.players.map(&:user), users(:sevval)
  end

  test "joining a room you are already in takes you back to it" do
    room = game_sessions(:ilker_room)
    sign_in_as users(:deniz)

    assert_no_difference -> { room.players.count } do
      post game_sessions_join_path, params: { code: room.code }
    end
    assert_redirected_to game_session_path(room)
  end

  test "a bad code keeps the code and says the room was not found" do
    sign_in_as users(:sevval)

    post game_sessions_join_path, params: { code: "0000" }
    assert_response :unprocessable_entity
    assert_select ".code-entry--rejected[data-code-rejected-value=?]", "0000"
    assert_select ".rejection strong", text: "Room not found"
    assert_select "input[name=code][value=?]", "0000"
    assert_select ".code__cell", text: "0", count: 4
    assert_select "button", text: "Change the code"
  end

  test "a started or expired room is not found" do
    room = game_sessions(:ilker_room)
    sign_in_as users(:sevval)

    travel GameSession::JOINABLE_FOR + 1.minute do
      post game_sessions_join_path, params: { code: room.code }
      assert_select ".rejection strong", text: "Room not found"
    end

    room.update! started_at: Time.current
    post game_sessions_join_path, params: { code: room.code }
    assert_select ".rejection strong", text: "Room not found"
  end

  test "a full room turns away a sixth player" do
    room = game_sessions(:ilker_room)
    3.times { |index| room.join User.create!(email: "friend#{index}@rokapi.test", name: "Friend") }
    sign_in_as users(:sevval)

    post game_sessions_join_path, params: { code: room.code }
    assert_response :unprocessable_entity
    assert_select ".rejection strong", text: "Room full · 5/5"
    assert_select "input[name=code][value=?]", room.code
    assert_equal 5, room.players.count
  end

  test "in Turkish" do
    sign_in_as users(:sevval)

    post game_sessions_join_path, params: { code: "0000" }, headers: { "Accept-Language" => "tr" }
    assert_select ".rejection strong", text: "Oda bulunamadı"
    assert_select "button", text: "Kodu değiştir"
  end

  test "creating and joining as JSON" do
    sign_in_as users(:sevval)

    get new_game_sessions_multi_path, as: :json
    assert_equal 3, response.parsed_body["cards"].size
    assert_equal %w[ fun balanced dark ], response.parsed_body["tones"].pluck("key")

    post game_sessions_multi_path(format: :json), params: { game_session: { card: "fishing_village missing_child weather_reader", tone: "balanced", length: "short" } }, as: :json
    assert_response :created
    room = GameSession.find(response.parsed_body["id"])
    assert_equal room.code, response.parsed_body["code"]
    assert_equal game_session_url(room), response.location

    sign_in_as users(:deniz)
    post game_sessions_join_path(format: :json), params: { code: room.code }, as: :json
    assert_response :created
    assert_equal game_session_url(room), response.location

    post game_sessions_join_path(format: :json), params: { code: "0000" }, as: :json
    assert_response :unprocessable_entity
    assert_equal "Room not found", response.parsed_body["error"]
  end
end
