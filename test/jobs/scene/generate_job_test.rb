require "test_helper"

class Scene::GenerateJobTest < ActiveSupport::TestCase
  test "a narrator that keeps failing leaves the scene stalled" do
    game_session = game_sessions(:ilker_solo)
    game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host)

    stub_llm(FakeChat.new("Anlatı geldi ama yapı yok.")) do
      job = Scene::GenerateJob.new(game_session)

      2.times { job.perform_now }
      assert game_session.current_scene.narrating?

      assert_raises Narrator::MalformedResponse do
        job.perform_now
      end
    end

    assert game_session.current_scene.failed?
  end
end
