require "test_helper"

class ChoiceTest < ActiveSupport::TestCase
  setup do
    @scene = game_sessions(:ilker_solo).scenes.create! position: 1,
      active_player: players(:ilker_solo_host), state: :choosing, title: "Eski Han"
    @choice = @scene.choices.create! label: "Çekmeceyi zorla", stat: "strength",
      modifier: 3, difficulty: 14, difficulty_label: "orta"
  end

  test "choose! marks the choice and moves the scene to rolling" do
    @choice.choose!

    assert @choice.reload.chosen?
    assert @scene.reload.rolling?
  end

  test "a scene accepts only one chosen choice" do
    other = @scene.choices.create! label: "Defteri oku", stat: "intelligence",
      modifier: -1, difficulty: 10, difficulty_label: "kolay"
    @choice.choose!

    assert_raises(Scene::OutOfTurn) { other.choose! }
  end

  test "roll! happens once, on the chosen choice of a rolling scene" do
    assert_raises(Scene::OutOfTurn) { @choice.roll!(by: players(:ilker_solo_host)) }

    @choice.choose!
    roll = @choice.roll!(by: players(:ilker_solo_host))

    assert @scene.reload.played?
    assert_includes 1..Roll::DIE, roll.value
    assert_equal 3, roll.modifier
    assert_equal 14, roll.target
    assert_equal roll.value + roll.modifier, roll.total
    assert_equal roll.total >= roll.target, roll.success?

    assert_equal Roll::REEL_CELLS, roll.faces.size
    assert_equal roll.value, roll.faces.last, "the reel must come to rest on the rolled value"
    assert_equal roll.faces, roll.faces, "the reel must not reshuffle between renders"
    assert_equal roll.faces.size, roll.faces.uniq.size

    assert_raises(Scene::OutOfTurn) { @choice.roll!(by: players(:ilker_solo_host)) }
  end

  test "hp effects clamp between zero and max" do
    @choice.choose!
    roll = @choice.roll!(by: players(:ilker_solo_host))

    roll.resolve! resolution: "Ağır darbe.", effects: { "hp" => -99 }
    assert_equal 0, characters(:ilker_hero).reload.hp

    roll.update! resolution: nil
    roll.resolve! resolution: "Mucizevi şifa.", effects: { "hp" => 999 }
    assert_equal characters(:ilker_hero).max_hp, characters(:ilker_hero).reload.hp
  end
end
