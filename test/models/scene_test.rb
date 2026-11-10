require "test_helper"

class SceneTest < ActiveSupport::TestCase
  test "a scene without a title is headed by its adventure" do
    scene = game_sessions(:ilker_solo).scenes.new(position: 1, active_player: players(:ilker_solo_host))
    assert_equal "A fog-bound fishing village", scene.heading

    scene.title = "The Old Inn"
    assert_equal "The Old Inn", scene.heading
  end
end
