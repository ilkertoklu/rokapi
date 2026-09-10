require "test_helper"

class Scene::NarrateJobTest < ActiveSupport::TestCase
  test "a narrator that keeps failing leaves the scene stalled" do
    game_session = game_sessions(:ilker_solo)
    scene = game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host)

    stub_llm(FakeChat.new("Prose arrived but no structure.")) do
      job = Scene::NarrateJob.new(scene)

      2.times { job.perform_now }
      assert game_session.current_scene.narrating?

      assert_raises Narrator::MalformedResponse do
        job.perform_now
      end
    end

    assert game_session.current_scene.stalled?
  end

  test "a rejected narrator stalls the scene without retrying" do
    game_session = game_sessions(:ilker_solo)
    scene = game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host)

    stub_llm(broken_chat(RubyLLM::UnauthorizedError.new(nil, "bad key"))) do
      assert_raises RubyLLM::UnauthorizedError do
        Scene::NarrateJob.new(scene).perform_now
      end
    end

    assert game_session.current_scene.stalled?
  end

  test "a failure the narrator never anticipated still stalls the scene" do
    game_session = game_sessions(:ilker_solo)
    scene = game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host)

    stub_llm(broken_chat(Faraday::TimeoutError.new)) do
      assert_raises Faraday::TimeoutError do
        Scene::NarrateJob.new(scene).perform_now
      end
    end

    assert game_session.current_scene.stalled?
  end

  private
    def broken_chat(error)
      Object.new.tap do |chat|
        chat.define_singleton_method(:with_instructions) { |*| chat }
        chat.define_singleton_method(:with_schema) { |*| chat }
        chat.define_singleton_method(:ask) { |*| raise error }
      end
    end
end
