require "test_helper"

class Scene::NarrateJobTest < ActiveJob::TestCase
  setup do
    @game_session = game_sessions(:ilker_solo)
    @scene = @game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host)
  end

  test "a narrator that cannot rewrite its reply leaves the scene stalled without retrying" do
    stub_understudy(*Array.new(1 + Narrator::REWRITES, "Prose arrived but no structure.")) do
      assert_no_enqueued_jobs only: Scene::NarrateJob do
        assert_raises Narrator::MalformedResponse do
          Scene::NarrateJob.new(@scene).perform_now
        end
      end
    end

    assert @game_session.current_scene.stalled?
  end

  test "a provider error is retried" do
    stub_understudy(nil) do
      assert_enqueued_with job: Scene::NarrateJob do
        Scene::NarrateJob.new(@scene).perform_now
      end
    end

    assert_not @game_session.current_scene.stalled?
  end

  test "a provider that keeps failing leaves the scene stalled" do
    job = Scene::NarrateJob.new(@scene)

    stub_understudy(nil) do
      2.times { job.perform_now }
      assert_raises(RubyLLM::ServerError) { job.perform_now }
    end

    assert @game_session.current_scene.stalled?
  end

test "the narrator speaks the default locale whatever the page that woke it" do
  I18n.with_locale(:tr) { @scene.narrate_later }
  request = stub_understudy(SCENE_RESPONSE) { perform_enqueued_jobs }.sole

  assert_includes request["system"], "Tone: Balanced"
end
end
