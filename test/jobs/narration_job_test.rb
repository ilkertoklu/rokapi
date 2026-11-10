require "test_helper"

class NarrationJobTest < ActiveJob::TestCase
  setup do
    @scene = game_sessions(:ilker_solo).scenes.create! position: 1, active_player: players(:ilker_solo_host), state: :choosing
    choice = @scene.choices.create! label: "Force the door", stat: "strength", modifier: 0, target: 10
    @roll = choice.create_roll! player: players(:ilker_solo_host), value: 12, status_modifier: 0
  end

  test "a game's scene and roll narrations wait for each other" do
    assert_equal Scene::NarrateJob.new(@scene).concurrency_key, Roll::NarrateJob.new(@roll).concurrency_key
  end

  test "narrations of different games run side by side" do
    other = game_sessions(:deniz_solo).scenes.create! position: 1, active_player: players(:deniz_solo_host)

    assert_not_equal Scene::NarrateJob.new(@scene).concurrency_key, Scene::NarrateJob.new(other).concurrency_key
  end
end
