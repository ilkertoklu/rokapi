require "test_helper"

class SoloSetupFlowTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:sevval)
    @valid_stats = Character.base_stats_for("warrior")
      .merge("strength" => 16, "constitution" => 15, "charisma" => 14)
  end

  test "setting up a solo adventure from mode pick to waiting screen" do
    get new_game_session_path
    assert_select "h2", text: "Tek kişilik"

    get new_game_session_path(mode: :solo)
    assert_select ".option__title", text: "Kayıp Kervan"
    assert_select ".option__title", text: "Sürpriz"

    post game_sessions_path, params: {
      game_session: { adventure_id: adventures(:kayip_kervan).id, tone: "dark", length: "short" }
    }
    game_session = users(:sevval).game_sessions.sole
    assert_redirected_to new_game_session_character_path(game_session)

    post game_session_character_path(game_session), params: {
      character: { race: "elf", klass: "warrior", background: "traveler", stats: @valid_stats }
    }
    assert_redirected_to game_session_path(game_session)

    follow_redirect!
    assert_select "h1", text: "Kayıp Kervan"
    assert_select "h2", text: "Anlatıcı hazırlanıyor"
    assert game_session.reload.playing?
    assert game_session.player_for(users(:sevval)).ready?
  end

  test "surprise adventures have no adventure record" do
    post game_sessions_path, params: { game_session: { adventure_id: "", tone: "fun", length: "medium" } }

    game_session = users(:sevval).game_sessions.sole
    assert_nil game_session.adventure
    assert_equal "Sürpriz macera", game_session.title
  end

  test "invalid stat allocation is rejected" do
    game_session = create_solo_session

    post game_session_character_path(game_session), params: {
      character: { race: "elf", klass: "warrior", background: "traveler",
                   stats: Character.base_stats_for("warrior") }
    }
    assert_redirected_to new_game_session_character_path(game_session)
    assert_nil game_session.player_for(users(:sevval)).character
  end

  test "tampered setup values fall back to defaults instead of erroring" do
    post game_sessions_path, params: {
      game_session: { adventure_id: "999999", tone: "hacked", length: "hacked" }
    }

    game_session = users(:sevval).game_sessions.sole
    assert_redirected_to new_game_session_character_path(game_session)
    assert_nil game_session.adventure
    assert game_session.balanced?
    assert game_session.medium?
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
    assert_select "h2", text: "Maceraya devam et"
    assert_select "a[href=?]", game_session_path(game_session)
  end

  private
    def create_solo_session
      post game_sessions_path, params: {
        game_session: { adventure_id: adventures(:kayip_kervan).id, tone: "balanced", length: "short" }
      }
      users(:sevval).game_sessions.sole
    end
end
