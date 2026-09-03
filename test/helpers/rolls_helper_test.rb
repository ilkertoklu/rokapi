require "test_helper"

class RollsHelperTest < ActionView::TestCase
  setup do
    scene = game_sessions(:ilker_solo).scenes.create! position: 1, active_player: players(:ilker_solo_host),
      state: :choosing, title: "Sınama"
    choice = scene.choices.create! label: "Dene", stat: "strength", modifier: 3, difficulty: 14, difficulty_label: "orta"
    @roll = choice.create_roll! player: players(:ilker_solo_host), value: 14, modifier: 3, status_modifier: 0, target: 14
  end

  test "the reel comes to rest on the rolled value and never reshuffles" do
    faces = die_reel_faces(@roll)

    assert_equal RollsHelper::REEL_CELLS, faces.size
    assert_equal @roll.value, faces.last
    assert_equal faces.size, faces.uniq.size
    assert_equal faces, die_reel_faces(@roll)
  end

  test "the verdict shouts only at the extremes" do
    assert_equal "BAŞARILI", outcome_verdict(@roll)

    @roll.value = 20
    assert_equal "KRİTİK BAŞARI!", outcome_verdict(@roll)

    @roll.value = 1
    @roll.success = false
    assert_equal "FELAKET!", outcome_verdict(@roll)
  end
end
