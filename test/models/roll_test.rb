require "test_helper"

class RollTest < ActiveSupport::TestCase
  setup do
    @scene = game_sessions(:ilker_solo).scenes.create! position: 1,
      active_player: players(:ilker_solo_host), state: :choosing, title: "Trial"
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
    roll = roll_with(value: 1, target: 8, modifier: 10)

    assert roll.success?
    assert_equal :solid, roll.grade
  end

  test "effects reach the inventory and the statuses" do
    character = characters(:ilker_hero)
    character.status_effects.create! name: "Dragging Leg", modifier: -1, expires_when: "until it eases"
    roll = roll_with(value: 9, target: 12)

    roll.resolve resolution: "You find a salve in the chest, but you come out soaked.", effects: {
      "hp" => -2,
      "items_gained" => [ { "name" => "Yellow salve", "kind" => "instant", "description" => "", "hp" => 5, "uses" => 1 } ],
      "items_lost" => [ "Inn ledger" ],
      "statuses_gained" => [ { "name" => "Soaked Through", "modifier" => -2, "turns" => 2, "expires_when" => "" } ],
      "statuses_lost" => [ "Dragging Leg" ] }

    assert_equal 31 - 2, character.reload.hp
    assert character.items.usable.exists?(name: "Yellow salve")
    assert_not character.items.exists?(name: "Inn ledger")
    assert_equal 2, character.status_effects.find_by!(name: "Soaked Through").turns_left
    assert_not character.status_effects.exists?(name: "Dragging Leg")
    assert_equal [ "Yellow salve" ], roll.reload.items_gained.pluck("name")
    assert_equal [ "Soaked Through" ], roll.statuses_gained.pluck("name")
  end

  test "health follows the grade" do
    success = roll_with(value: 20, target: 12)
    success.resolve resolution: "You fly through.", effects: { "hp" => -4 }
    assert_equal 0, success.reload.hp_change, "a success does not hurt"

    heavy = roll_with(value: 2, target: 12)
    heavy.resolve resolution: "You fall hard.", effects: { "hp" => -30 }
    assert_equal(-9, heavy.reload.hp_change, "a heavy failure costs at most 9")
    assert_equal 31 - 9, characters(:ilker_hero).reload.hp
  end

  test "a positive status is earned only by a natural twenty" do
    boon = { "statuses_gained" => [ { "name" => "Sure Grip", "modifier" => 2, "turns" => 2, "expires_when" => "" } ] }

    brilliant = roll_with(value: 19, target: 8)
    brilliant.resolve resolution: "The door opens.", effects: boon
    assert_empty characters(:ilker_hero).status_effects, "a brilliant success must not stack a bonus"
    assert_empty brilliant.reload.statuses_gained

    roll_with(value: 20, target: 8).resolve resolution: "The door opens.", effects: boon
    assert characters(:ilker_hero).status_effects.exists?(name: "Sure Grip")
  end

  test "a granted item and status arrive within their ranges" do
    roll = roll_with(value: 9, target: 12)

    roll.resolve resolution: "You find a salve in the chest, but you come out soaked.", effects: {
      "items_gained" => [ { "name" => "Yellow salve", "kind" => "instant", "description" => "", "hp" => 5, "uses" => 0 },
                          { "name" => "Old map", "kind" => "passive", "description" => "Shows the pass", "hp" => 4, "uses" => 3 } ],
      "statuses_gained" => [ { "name" => "Soaked Through", "modifier" => -5, "turns" => 0, "expires_when" => "" } ] }

    salve = characters(:ilker_hero).items.find_by!(name: "Yellow salve")
    assert_equal [ 1, 5 ], [ salve.uses_left, salve.hp_effect ], "uses must be at least 1 or the item arrives dead"
    map = characters(:ilker_hero).items.find_by!(name: "Old map")
    assert_equal [ nil, 0 ], [ map.uses_left, map.hp_effect ], "only an instant item is used up"

    soaked = characters(:ilker_hero).status_effects.find_by!(name: "Soaked Through")
    assert_equal(-2, soaked.modifier, "modifiers are clamped to the dice range")
    assert_equal 2, soaked.turns_left, "an open-ended status would never wear off"
    assert_nil soaked.expires_when
    assert_equal(-2, roll.reload.statuses_gained.sole["modifier"], "the roll keeps the effects as applied")
  end

  test "a resolution may replace an item it takes away" do
    roll_with(value: 9, target: 12).resolve resolution: "Your flask breaks, but you find another in the wreckage.", effects: {
      "items_gained" => [ { "name" => "Healing potion", "kind" => "instant", "description" => "", "hp" => 6, "uses" => 1 } ],
      "items_lost" => [ "Healing potion" ] }

    potions = characters(:ilker_hero).items.usable.where(name: "Healing potion")
    assert_equal 6, potions.sole.hp_effect, "the lost copy goes first so the replacement survives"
  end

  test "statuses beyond the limit are dropped" do
    character = characters(:ilker_hero)
    character.status_effects.create! name: "Bruised Ribs", modifier: -1, turns_left: 3
    character.status_effects.create! name: "Soaked Through", modifier: -1, turns_left: 3
    burned = { "name" => "Burned Palms", "modifier" => -1, "turns" => 9, "expires_when" => "" }

    roll = roll_with(value: 9, target: 12)
    roll.resolve resolution: "You get burned.", effects: { "statuses_gained" => [ burned ] }
    assert_not character.status_effects.exists?(name: "Burned Palms")
    assert_empty roll.reload.statuses_gained

    roll_with(value: 9, target: 12).resolve resolution: "You get burned.", effects: { "statuses_gained" => [ burned ], "statuses_lost" => [ "Soaked Through" ] }
    assert_equal 3, character.status_effects.find_by!(name: "Burned Palms").turns_left, "a status lasts 3 turns at most"
  end

  test "a grant of unknown kind applies nothing" do
    roll = roll_with(value: 9, target: 12)

    assert_no_difference -> { Item.count } do
      assert_raises(ArgumentError) do
        roll.resolve resolution: "You find something.", effects: { "items_gained" => [ { "name" => "Old charm", "kind" => "relic" } ] }
      end
    end

    assert_nil roll.reload.resolution
  end

  private
    def roll_with(value:, target:, modifier: 0)
      choice = @scene.choices.create! label: "Try it", stat: "strength", modifier: modifier,
        target: target
      choice.create_roll! player: players(:ilker_solo_host), value: value, status_modifier: 0
    end
end
