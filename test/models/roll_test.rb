require "test_helper"

class RollTest < ActiveSupport::TestCase
  setup do
    @scene = game_sessions(:ilker_solo).scenes.create! position: 1,
      active_player: players(:ilker_solo_host), state: :choosing, title: "Sınama"
  end

  test "grades scale with the die and the margin" do
    assert_equal :critical, roll_with(value: 20, target: 12).grade
    assert_equal :brilliant, roll_with(value: 16, target: 8).grade
    assert_equal :solid, roll_with(value: 14, target: 11).grade
    assert_equal :narrow, roll_with(value: 12, target: 12).grade
    assert_equal :failure, roll_with(value: 9, target: 12).grade
    assert_equal :heavy, roll_with(value: 5, target: 12).grade
    assert_equal :catastrophe, roll_with(value: 1, target: 12).grade
  end

  test "the margin measures the distance to the target" do
    assert_equal 8, roll_with(value: 16, target: 8).margin
    assert_equal(-7, roll_with(value: 5, target: 12).margin)
  end

  test "a natural one that still clears the target is no catastrophe" do
    roll = roll_with(value: 1, target: 5, modifier: 6)

    assert roll.success?
    assert_equal :solid, roll.grade
  end

  private
    def roll_with(value:, target:, modifier: 0)
      choice = @scene.choices.create! label: "Dene", stat: "strength", modifier: modifier,
        difficulty: target, difficulty_label: "orta"
      choice.create_roll! player: players(:ilker_solo_host), value: value,
        modifier: modifier, status_modifier: 0, target: target
    end
end
