require "test_helper"

class GameSessionTest < ActiveSupport::TestCase
  test "creating a session enrolls the creator as host" do
    game_session = GameSession.create!(creator: users(:ilker), mode: :solo, adventure: adventures(:golun_sirri))

    player = game_session.players.sole
    assert_equal users(:ilker), player.user
    assert player.host?
    assert game_session.lobby?
  end

  test "title falls back for surprise adventures" do
    assert_equal "Kayıp Kervan", game_sessions(:ilker_solo).title
    assert_equal "Sürpriz macera", GameSession.new.title
  end

  test "starts when every player is ready" do
    game_session = game_sessions(:ilker_solo)

    game_session.start_when_ready!
    assert game_session.lobby?

    game_session.players.sole.update!(ready: true)
    game_session.start_when_ready!
    assert game_session.reload.playing?
  end

  test "destroying a session cascades through every play record" do
    game_session = game_sessions(:ilker_solo)
    scene = game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host),
      state: :choosing, title: "Eski Han"
    choice = scene.choices.create! label: "Defteri oku", stat: "intelligence",
      modifier: -1, difficulty: 10, difficulty_label: "kolay"
    choice.choose!
    choice.roll!(by: players(:ilker_solo_host))
    LlmCall.record! game_session: game_session, purpose: :scene,
      response: RubyLLM::Message.new(role: :assistant, content: "x", model_id: "gpt-5-mini",
                                     input_tokens: 10, output_tokens: 10)

    game_session.destroy

    assert_empty Scene.where(game_session_id: game_session.id)
    assert_empty Roll.where(choice_id: choice.id)
    assert_empty LlmCall.where(game_session_id: game_session.id)
    assert_empty Player.where(game_session_id: game_session.id)
  end

  test "ongoing scope" do
    assert_includes GameSession.ongoing, game_sessions(:ilker_solo)

    game_sessions(:ilker_solo).finished!
    assert_not_includes GameSession.ongoing, game_sessions(:ilker_solo)
  end
end
