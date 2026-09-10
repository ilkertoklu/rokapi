require "test_helper"

class RollsHelperTest < ActionView::TestCase
  setup do
    scene = game_sessions(:ilker_solo).scenes.create! position: 1, active_player: players(:ilker_solo_host),
      state: :choosing, title: "Trial"
    choice = scene.choices.create! label: "Try it", stat: "strength", modifier: 3, target: 14
    @roll = choice.create_roll! player: players(:ilker_solo_host), value: 14, status_modifier: 0
  end

  test "the reel comes to rest on the rolled value and never reshuffles" do
    faces = die_reel_faces(@roll)

    assert_equal RollsHelper::REEL_CELLS, faces.size
    assert_equal @roll.value, faces.last
    assert_equal faces.size, faces.uniq.size
    assert_equal faces, die_reel_faces(@roll)
  end

  test "the verdict shouts only at the extremes" do
    assert_equal "SUCCESS", outcome_verdict(@roll)

    @roll.value = 20
    assert_equal "CRITICAL SUCCESS!", outcome_verdict(@roll)

    @roll.value = 1
    @roll.success = false
    assert_equal "CATASTROPHE!", outcome_verdict(@roll)
  end
end
