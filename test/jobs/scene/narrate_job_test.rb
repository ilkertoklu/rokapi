require "test_helper"

class Scene::NarrateJobTest < ActiveJob::TestCase
  test "a narrator that cannot rewrite its reply leaves the scene stalled without retrying" do
    game_session = game_sessions(:ilker_solo)
    scene = game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host)

    stub_llm(FakeReply.new("Prose arrived but no structure.")) do
      assert_no_enqueued_jobs only: Scene::NarrateJob do
        assert_raises Narrator::MalformedResponse do
          Scene::NarrateJob.new(scene).perform_now
        end
      end
    end

    assert game_session.current_scene.stalled?
  end

  test "a provider error is retried" do
    game_session = game_sessions(:ilker_solo)
    scene = game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host)

    stub_llm(FakeReply.failing(RubyLLM::ServerError.new("overloaded"))) do
      assert_enqueued_with job: Scene::NarrateJob do
        Scene::NarrateJob.new(scene).perform_now
      end
    end

    assert_not game_session.current_scene.stalled?
  end

  test "a rejected narrator stalls the scene without retrying" do
    game_session = game_sessions(:ilker_solo)
    scene = game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host)

    stub_llm(FakeReply.failing(RubyLLM::UnauthorizedError.new("bad key"))) do
      assert_raises RubyLLM::UnauthorizedError do
        Scene::NarrateJob.new(scene).perform_now
      end
    end

    assert game_session.current_scene.stalled?
  end

  test "a failure the narrator never anticipated still stalls the scene" do
    game_session = game_sessions(:ilker_solo)
    scene = game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host)

    stub_llm(FakeReply.failing(Faraday::TimeoutError.new)) do
      assert_raises Faraday::TimeoutError do
        Scene::NarrateJob.new(scene).perform_now
      end
    end

    assert game_session.current_scene.stalled?
  end
end
