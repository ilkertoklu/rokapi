require "test_helper"

class JsonPlayFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    sign_in_as users(:sevval)
  end

  test "playing a solo adventure from setup to victory as JSON" do
    get new_game_sessions_solo_path, as: :json
    assert_response :success
    assert_equal 3, response.parsed_body["cards"].size
    assert_equal 7, response.parsed_body["lengths"].find { it["key"] == "short" }["scenes"]
    card = response.parsed_body["cards"].second

    post game_sessions_solo_path, params: { game_session: { card: card["key"], tone: "balanced", length: "short" } }, as: :json
    assert_response :created
    game_session = users(:sevval).game_sessions.sole
    assert_equal game_session_url(game_session), response.location

    get new_game_session_character_path(game_session), as: :json
    assert_response :success
    assert_equal Character::FREE_POINTS, response.parsed_body["free_points"]
    assert_equal 14, response.parsed_body["klasses"].find { it["key"] == "warrior" }["base_stats"]["strength"]

    get game_session_path(game_session), as: :json
    assert_equal card.slice("place", "trouble", "figure"), response.parsed_body["card"]
    assert_nil response.parsed_body["character"]
    assert_not response.parsed_body["started"]

    stub_understudy(*PLANNING, SCENE_RESPONSE) do
      perform_enqueued_jobs do
        post game_session_character_path(game_session), params: { character: warrior }, as: :json
      end
    end
    assert_response :created

    get game_session_path(game_session), as: :json
    game = response.parsed_body
    assert game["your_turn"]
    assert_equal 31, game["character"]["max_hp"]
    assert_includes game["character"]["items"].pluck("name"), "Longsword"
    scene = game["scenes"].sole
    assert_equal [ "The Old Inn", "choosing" ], scene.values_at("title", "state")
    assert_match "Rain hammers the inn's", scene["narration"]
    assert_equal %w[intelligence strength wisdom], scene["choices"].pluck("stat")

    choice = scene["choices"].find { it["stat"] == "strength" }
    post game_session_choice_selection_path(game_session, choice["id"]), as: :json
    assert_response :no_content

    get game_session_path(game_session), as: :json
    assert_equal "rolling", response.parsed_body["scenes"].last["state"]

    stub_understudy(OUTCOME_RESPONSE) do
      with_die(2) { perform_enqueued_jobs { post game_session_roll_path(game_session), as: :json } }
    end
    assert_response :no_content

    get game_session_path(game_session), as: :json
    roll = response.parsed_body["scenes"].last["roll"]
    assert roll["resolved"]
    assert_not roll["acknowledged"]
    assert_equal "The drawer opens, but you cut your hand.", roll["resolution"]
    assert_equal(-4, roll["effects"]["hp"])

    game_session.current_scene.update! position: game_session.scene_budget - 1

    stub_understudy(SECOND_SCENE_RESPONSE) do
      perform_enqueued_jobs { post game_session_acknowledgement_path(game_session), as: :json }
    end
    assert_response :no_content

    get game_session_path(game_session), as: :json
    last_scene = response.parsed_body["scenes"].last
    assert_equal [ 7, "choosing", false ], last_scene.values_at("position", "state", "finale")

    post game_session_choice_selection_path(game_session, last_scene["choices"].first["id"]), as: :json
    stub_understudy(ENDING_RESPONSE) do
      with_die(2) { perform_enqueued_jobs { post game_session_roll_path(game_session), as: :json } }
    end

    get game_session_path(game_session), as: :json
    game = response.parsed_body
    assert game["finished"]
    assert_equal "victory", game["outcome"], "a lost last roll sets the price, not the ending"
    assert game["scenes"].last["finale"]
    assert_match "the caravan bells echo", game["scenes"].last["roll"]["resolution"]
    assert_equal 0.0, game["cost"]
  end

  test "a move out of turn is a conflict" do
    game_session = play_to_choices

    post game_session_roll_path(game_session), as: :json
    assert_response :conflict
  end

  test "a move after the game is over is a conflict that says so" do
    game_session = play_to_choices
    game_session.finish

    post game_session_roll_path(game_session), as: :json
    assert_response :conflict
    assert_equal "The game is over.", response.parsed_body["error"]
  end

  test "signed out, a request is unauthorized instead of sent to the welcome page" do
    delete session_path

    get game_session_path(game_sessions(:ilker_solo)), as: :json
    assert_response :unauthorized

    get game_session_path(game_sessions(:ilker_solo))
    assert_redirected_to welcome_path
  end

  test "an invalid character is rejected with its errors" do
    post game_sessions_solo_path, params: { game_session: { card: "fishing_village missing_child weather_reader", tone: "balanced", length: "short" } }, as: :json
    game_session = users(:sevval).game_sessions.sole

    post game_session_character_path(game_session), params: { character: warrior.merge(stats: { strength: 18 }) }, as: :json
    assert_response :unprocessable_entity
    assert response.parsed_body["stats"].present?
  end

  test "an invalid game is rejected with its errors" do
    post game_sessions_solo_path, params: { game_session: { card: "nowhere", tone: "balanced", length: "short" } }, as: :json
    assert_response :unprocessable_entity
    assert response.parsed_body["place"].present?
  end

  test "someone else's game is not found" do
    get game_session_path(game_sessions(:deniz_solo)), as: :json
    assert_response :not_found
  end

  test "drinking a potion" do
    game_session = play_to_choices
    character = users(:sevval).players.sole.character
    potion = character.items.create! name: "Healing potion", kind: "instant", hp_effect: 7, uses_left: 1
    character.update! hp: 10

    post game_session_item_use_path(game_session, potion), as: :json
    assert_response :no_content
    assert_equal 17, character.reload.hp

    post game_session_item_use_path(game_session, potion), as: :json
    assert_response :not_found
  end

  private
    def warrior
      { race: "elf", klass: "warrior", background: "traveler",
        stats: Character::Klass.fetch("warrior").base_stats.merge("strength" => 16, "constitution" => 15, "charisma" => 14) }
    end

    def play_to_choices
      post game_sessions_solo_path, params: { game_session: { card: "fishing_village missing_child weather_reader", tone: "balanced", length: "short" } }, as: :json
      game_session = users(:sevval).game_sessions.sole

      stub_understudy(*PLANNING, SCENE_RESPONSE) do
        perform_enqueued_jobs { post game_session_character_path(game_session), params: { character: warrior }, as: :json }
      end

      game_session
    end
end
