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

  test "ongoing scope" do
    assert_includes GameSession.ongoing, game_sessions(:ilker_solo)

    game_sessions(:ilker_solo).finished!
    assert_empty GameSession.ongoing
  end
end
