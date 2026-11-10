require "test_helper"

class RollTest < ActiveSupport::TestCase
  CLUES_PLAN = "Clues:\n1. Mara's shawl hangs on the lighthouse door.\n2. The boy's boots stand dry.\n3. The press gang's list carries his name."

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
      "carries" => [ "Longsword", "Healing potion", { "name" => "Yellow salve", "kind" => "instant", "description" => "", "hp" => 5, "uses" => 1 } ],
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

  test "an outcome that lands after a stall is no longer stalled" do
    roll = roll_with(value: 15, target: 12)
    roll.stall_narration

    roll.resolve resolution: "The door gives.", effects: {}

    assert_not roll.reload.stalled?
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
      "carries" => [ "Longsword", "Healing potion", "Inn ledger",
                     { "name" => "Yellow salve", "kind" => "instant", "description" => "", "hp" => 5, "uses" => 0 },
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

  test "what the hero no longer carries leaves the sheet, and what is told anew is rewritten" do
    roll = roll_with(value: 9, target: 12)
    roll.resolve resolution: "The guards take the ledger and notch your blade.", effects: {
      "carries" => [ "Longsword (notched)", "Healing potion (instant: +7 health, 1 use)" ] }

    character = characters(:ilker_hero).reload
    assert_equal [ "Healing potion", "Longsword" ], character.items.carried.pluck(:name).sort
    assert_equal "notched", character.items.find_by!(name: "Longsword").description
    assert_equal [ "Longsword", "Inn ledger" ], roll.reload.items_lost
  end

  test "each thing on the sheet is kept or told where it is now, and what is told anew under its own name" do
    roll = roll_with(value: 9, target: 12)
    roll.resolve resolution: "You hand the ledger to the guard, and your blade notches on the gate.", effects: {
      "carries" => { "Longsword" => { "description" => "notched" }, "Healing potion" => true, "Inn ledger" => "with the guard at the gate",
                     "Gate key" => { "kind" => "quest", "description" => "The guard's spare" } } }

    character = characters(:ilker_hero).reload
    assert_equal [ "Gate key", "Healing potion", "Longsword" ], character.items.carried.pluck(:name).sort
    assert_equal "notched", character.items.find_by!(name: "Longsword").description
    assert character.items.quest.exists?(name: "Gate key")
    assert_equal [ "Longsword", "Inn ledger" ], roll.reload.items_lost
  end

  test "an instant item is the player's to use, so leaving it off the list does not spend it" do
    roll_with(value: 9, target: 12).resolve resolution: "You drink deep.", effects: { "carries" => [ "Longsword", "Inn ledger" ] }

    assert characters(:ilker_hero).items.usable.exists?(name: "Healing potion")
  end

  test "a listed instant item keeps its own uses whatever the block says" do
    roll_with(value: 9, target: 12).resolve resolution: "You check your flask.", effects: {
      "carries" => [ "Longsword", "Inn ledger", { "name" => "Healing potion", "kind" => "instant", "hp" => 20, "uses" => 9 } ] }

    potion = characters(:ilker_hero).items.usable.sole
    assert_equal [ 7, 1 ], [ potion.hp_effect, potion.uses_left ]
  end

  test "a block that does not say what the hero carries leaves the inventory alone" do
    assert_no_difference -> { characters(:ilker_hero).items.carried.count } do
      roll_with(value: 9, target: 12).resolve resolution: "You stumble.", effects: { "hp" => -2 }
    end
  end

  test "a status the story must lift outlasts the turns until a block lifts it" do
    arrow = { "name" => "Arrow in the shoulder", "modifier" => -1, "expires_when" => "until the arrow is drawn" }
    roll_with(value: 9, target: 12).resolve resolution: "The arrow takes you high in the shoulder.", effects: { "statuses_gained" => [ arrow ] }

    4.times { roll_with(value: 9, target: 12).resolve resolution: "You stumble on.", effects: {} }
    status = characters(:ilker_hero).status_effects.find_by!(name: "Arrow in the shoulder")
    assert_equal [ nil, "until the arrow is drawn" ], [ status.turns_left, status.expires_when ]

    roll_with(value: 15, target: 12).resolve resolution: "Mara draws the arrow.", effects: { "statuses_lost" => [ "Arrow in the shoulder" ] }
    assert_empty characters(:ilker_hero).status_effects
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

  test "a grant of unknown kind or a bare name is carried as a passive item, and a grant without a name is dropped" do
    assert_difference -> { Item.count }, +2 do
      roll_with(value: 9, target: 12).resolve resolution: "You find something.", effects: {
        "carries" => [ "Longsword", "Healing potion", "Inn ledger", { "name" => "Old charm", "kind" => "relic" }, { "kind" => "quest" }, "Rope (frayed)" ] }
    end

    assert Item.find_by!(name: "Old charm").passive?
    assert_equal "frayed", Item.find_by!(name: "Rope").description
  end

  test "a roll records the clue its success won, whatever the reply says" do
    game_sessions(:ilker_solo).update! plan: CLUES_PLAN

    found = roll_with(value: 15, target: 12)
    found.resolve resolution: "Mara's shawl hangs on the lighthouse door.", effects: { "clue" => 3 }

    missed = roll_with(value: 5, target: 12)
    missed.resolve resolution: "The beach is empty.", effects: { "clue" => 2 }

    later = roll_with(value: 15, target: 12)
    later.resolve resolution: "The boots under the stairs are dry.", effects: {}

    assert_equal 1, found.reload.effects["clue"]
    assert_not missed.reload.effects.key?("clue")
    assert_equal 2, later.reload.effects["clue"]
  end

  test "a roll wins no clue from a plan that numbers none, nor in the last scene" do
    unnumbered = roll_with(value: 15, target: 12)
    unnumbered.resolve resolution: "The beach is empty.", effects: { "clue" => 1 }

    game_sessions(:ilker_solo).update! plan: CLUES_PLAN
    @scene.update! position: game_sessions(:ilker_solo).scene_budget

    assert_not unnumbered.reload.effects.key?("clue")
    assert_nil roll_with(value: 15, target: 12).clue_won
  end

  test "a roll keeps what its reply says it changed for good" do
    marked = roll_with(value: 15, target: 12)
    marked.resolve resolution: "The keeper hands you the lamp room key.", effects: { "mark" => "The keeper trusts Ilker with the lamp room." }

    unmarked = roll_with(value: 15, target: 12)
    unmarked.resolve resolution: "The beach is empty.", effects: {}

    assert_equal "The keeper trusts Ilker with the lamp room.", marked.reload.effects["mark"]
    assert_not unmarked.reload.effects.key?("mark")
  end

  private
    def roll_with(value:, target:, modifier: 0)
      choice = @scene.choices.create! label: "Try it", stat: "strength", modifier: modifier,
        target: target
      choice.create_roll! player: players(:ilker_solo_host), value: value, status_modifier: 0
    end
end
