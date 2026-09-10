require "test_helper"

class SoloSetupFlowTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:sevval)
    @valid_stats = Character::Klass.fetch("warrior").base_stats
      .merge("strength" => 16, "constitution" => 15, "charisma" => 14)
  end

  test "setting up a solo adventure from mode pick to waiting screen" do
    get new_game_session_path
    assert_select ".page-head h1", text: "New adventure"
    assert_select ".pick__title", text: "Solo"
    assert_select "a[href=?]", new_game_sessions_solo_path

    get new_game_sessions_solo_path
    assert_select ".pick__title", text: "The Lost Caravan"
    assert_select ".pick__title", text: "Surprise"

    post game_sessions_solo_path, params: {
      game_session: { quest: "lost_caravan", tone: "dark", length: "short" }
    }
    game_session = users(:sevval).game_sessions.sole
    assert_redirected_to new_game_session_character_path(game_session)

    get new_game_session_character_path(game_session)
    assert_select "input[name=?][value=?]", "character[stats][strength]", "14"
    assert_select ".choice-description:not([hidden])", 3

    assert_enqueued_with job: Scene::NarrateJob do
      post game_session_character_path(game_session), params: {
        character: { race: "elf", klass: "warrior", background: "traveler", stats: @valid_stats }
      }
    end
    assert_redirected_to game_session_path(game_session)

    follow_redirect!
    assert_select ".location h1", text: "The Lost Caravan"
    assert_select ".writing", text: /The narrator is getting ready/
    assert game_session.reload.started?
    assert game_session.scenes.sole.narrating?
  end

  test "surprise adventures have no quest record" do
    post game_sessions_solo_path, params: { game_session: { quest: "", tone: "fun", length: "medium" } }

    game_session = users(:sevval).game_sessions.sole
    assert_nil game_session.quest
    assert_equal "Surprise adventure", game_session.title
  end

  test "invalid stat allocation is rejected" do
    game_session = create_solo_session

    post game_session_character_path(game_session), params: {
      character: { race: "elf", klass: "warrior", background: "traveler",
                   stats: Character::Klass.fetch("warrior").base_stats }
    }
    assert_redirected_to new_game_session_character_path(game_session)
    assert_nil game_session.player_for(users(:sevval)).character
  end

  test "tampered setup values are refused" do
    post game_sessions_solo_path, params: { game_session: { quest: "", tone: "hacked", length: "short" } }

    assert_redirected_to new_game_sessions_solo_path
    assert_equal "That setup is not valid. Check your picks.", flash[:alert]

    post game_sessions_solo_path, params: { game_session: { quest: "hacked", tone: "balanced", length: "short" } }

    assert_redirected_to new_game_sessions_solo_path
    assert_empty users(:sevval).game_sessions
  end

  test "session without a character redirects to character creation" do
    game_session = create_solo_session

    get game_session_path(game_session)
    assert_redirected_to new_game_session_character_path(game_session)
  end

  test "players with a character cannot reach the character form again" do
    game_session = create_solo_session
    post game_session_character_path(game_session), params: {
      character: { race: "elf", klass: "warrior", background: "traveler", stats: @valid_stats }
    }

    get new_game_session_character_path(game_session)
    assert_redirected_to game_session_path(game_session)

    assert_no_difference -> { Character.count } do
      post game_session_character_path(game_session), params: {
        character: { race: "human", klass: "bard", background: "noble", stats: @valid_stats }
      }
    end
    assert_redirected_to game_session_path(game_session)
  end

  test "other users cannot reach a foreign session" do
    get game_session_path(game_sessions(:ilker_solo))
    assert_response :not_found

    post game_session_character_path(game_sessions(:ilker_solo)), params: {
      character: { race: "elf", klass: "warrior", background: "traveler", stats: @valid_stats }
    }
    assert_response :not_found
  end

  test "home offers resuming the latest unfinished session" do
    game_session = create_solo_session

    get root_path
    assert_select ".resume__title", text: "Resume adventure"
    assert_select "a[href=?]", game_session_path(game_session)
  end

  private
    def create_solo_session
      post game_sessions_solo_path, params: {
        game_session: { quest: "lost_caravan", tone: "balanced", length: "short" }
      }
      users(:sevval).game_sessions.sole
    end
end
