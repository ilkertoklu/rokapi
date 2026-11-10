require "test_helper"

class SceneTest < ActiveSupport::TestCase
  test "a scene without a title is headed by its adventure" do
    scene = game_sessions(:ilker_solo).scenes.new(position: 1, active_player: players(:ilker_solo_host))
    assert_equal "A fog-bound fishing village", scene.heading

    scene.title = "The Old Inn"
    assert_equal "The Old Inn", scene.heading
  end

  test "the others wait in turn order after the active player" do
    room = game_sessions(:ilker_room)
    newcomer = room.players.create!(user: users(:sevval))
    scene = room.scenes.new(position: 1, active_player: players(:deniz_room_guest))

    assert_equal [ newcomer, players(:ilker_room_host) ], scene.others_in_turn_order
  end
end
