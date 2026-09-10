require "test_helper"

class ChoiceTest < ActiveSupport::TestCase
  setup do
    @scene = game_sessions(:ilker_solo).scenes.create! position: 1,
      active_player: players(:ilker_solo_host), state: :choosing, title: "The Old Inn"
    @choice = @scene.choices.create! label: "Force the drawer open", stat: "strength", modifier: 3, target: 14
  end

  test "choose marks the choice and moves the scene to rolling" do
    @choice.choose

    assert @choice.reload.chosen?
    assert @scene.reload.rolling?
  end

  test "a scene accepts only one chosen choice" do
    other = @scene.choices.create! label: "Read the ledger", stat: "intelligence", modifier: -1, target: 10
    @choice.choose

    assert_raises(Scene::OutOfTurn) { other.choose }
  end

  test "the target label follows the target" do
    assert_equal "easy", Choice.new(target: 10).difficulty
    assert_equal "medium", Choice.new(target: 12).difficulty
    assert_equal "hard", Choice.new(target: 16).difficulty
  end

  test "the dice are rolled once, on the chosen choice of a rolling scene" do
    assert_raises(Scene::OutOfTurn) { @scene.roll_dice(by: players(:ilker_solo_host)) }

    @choice.choose
    roll = @scene.roll_dice(by: players(:ilker_solo_host))

    assert @scene.reload.played?
    assert_includes 1..Roll::DIE, roll.value
    assert_equal 3, roll.modifier
    assert_equal 14, roll.target
    assert_equal roll.value + roll.modifier, roll.total
    assert_equal roll.total >= roll.target, roll.success?

    assert_raises(Scene::OutOfTurn) { @scene.roll_dice(by: players(:ilker_solo_host)) }
  end

  test "hp effects clamp between zero and max" do
    @choice.choose
    roll = @scene.roll_dice(by: players(:ilker_solo_host))

    roll.resolve resolution: "A heavy blow.", effects: { "hp" => -99 }
    assert_equal 0, characters(:ilker_hero).reload.hp

    roll.update! resolution: nil
    roll.resolve resolution: "A miraculous healing.", effects: { "hp" => 999 }
    assert_equal characters(:ilker_hero).max_hp, characters(:ilker_hero).reload.hp
  end
end
