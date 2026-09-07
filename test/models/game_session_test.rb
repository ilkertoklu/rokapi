require "test_helper"

class GameSessionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "creating a session enrolls the creator" do
    game_session = GameSession.create!(creator: users(:ilker), quest: "sunken_village")

    assert_equal users(:ilker), game_session.players.sole.user
    assert_equal game_session.players.sole, game_session.host
    assert_not game_session.started?
  end

  test "title falls back for surprise adventures" do
    assert_equal "Kayıp Kervan", game_sessions(:ilker_solo).title
    assert_equal "Sürpriz macera", GameSession.new.title
  end

  test "starts and calls the narrator once every player has a character" do
    game_session = game_sessions(:ilker_without_character)

    assert_no_enqueued_jobs only: Scene::NarrateJob do
      game_session.start_when_ready
    end
    assert_not game_session.started?
    assert_empty game_session.scenes

    players(:ilker_without_character_host).create_character! race: "human", klass: "warrior", background: "soldier",
      stats: Character::Klass.fetch("warrior").base_stats.merge("strength" => 16, "constitution" => 15, "charisma" => 14)

    assert_enqueued_with job: Scene::NarrateJob do
      game_session.start_when_ready
    end
    assert game_session.reload.started?
    assert game_session.scenes.sole.narrating?
  end

  test "destroying a session cascades through every play record" do
    game_session = game_sessions(:ilker_solo)
    scene = game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host),
      state: :choosing, title: "Eski Han"
    choice = scene.choices.create! label: "Defteri oku", stat: "intelligence",
      modifier: -1, target: 10
    choice.choose
    scene.roll_dice(by: players(:ilker_solo_host))
    LlmCall.record game_session: game_session, purpose: :scene,
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

    game_sessions(:ilker_solo).finish(:victory)
    assert_not_includes GameSession.ongoing, game_sessions(:ilker_solo)
  end
end
