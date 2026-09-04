require "test_helper"

class SoloSetupFlowTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:sevval)
    @valid_stats = Character::Klass.fetch("warrior").base_stats
      .merge("strength" => 16, "constitution" => 15, "charisma" => 14)
  end

  test "setting up a solo adventure from mode pick to waiting screen" do
    get new_game_session_path
    assert_select ".page-head h1", text: "Yeni macera"
    assert_select ".pick__title", text: "Tek kişilik"
    assert_select "a[href=?]", new_game_sessions_solo_path

    get new_game_sessions_solo_path
    assert_select ".pick__title", text: "Kayıp Kervan"
    assert_select ".pick__title", text: "Sürpriz"

    post game_sessions_solo_path, params: {
      game_session: { adventure_id: adventures(:kayip_kervan).id, tone: "dark", length: "short" }
    }
    game_session = users(:sevval).game_sessions.sole
    assert_redirected_to new_game_session_character_path(game_session)

    get new_game_session_character_path(game_session)
    assert_select "input[name=?][value=?]", "character[stats][strength]", "14"
    assert_select ".choice-description:not([hidden])", 3

    assert_enqueued_with job: Scene::GenerateJob, args: [ game_session ] do
      post game_session_character_path(game_session), params: {
        character: { race: "elf", klass: "warrior", background: "traveler", stats: @valid_stats }
      }
    end
    assert_redirected_to game_session_path(game_session)

    follow_redirect!
    assert_select ".location h1", text: "Kayıp Kervan"
    assert_select ".writing", text: /Anlatıcı hazırlanıyor/
    assert game_session.reload.playing?
  end

  test "surprise adventures have no adventure record" do
    post game_sessions_solo_path, params: { game_session: { adventure_id: "", tone: "fun", length: "medium" } }

    game_session = users(:sevval).game_sessions.sole
    assert_nil game_session.adventure
    assert_equal "Sürpriz macera", game_session.title
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
    post game_sessions_solo_path, params: { game_session: { adventure_id: "", tone: "hacked", length: "short" } }

    assert_redirected_to new_game_sessions_solo_path
    assert_equal "Kurulum geçersiz. Seçimlerini kontrol et.", flash[:alert]
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
    assert_select ".resume__title", text: "Maceraya devam et"
    assert_select "a[href=?]", game_session_path(game_session)
  end

  private
    def create_solo_session
      post game_sessions_solo_path, params: {
        game_session: { adventure_id: adventures(:kayip_kervan).id, tone: "balanced", length: "short" }
      }
      users(:sevval).game_sessions.sole
    end
end
