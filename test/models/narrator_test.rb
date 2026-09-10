require "test_helper"
require "turbo/broadcastable/test_helper"

class NarratorTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    @game_session = game_sessions(:ilker_solo)
    @game_session.advance
  end

  test "the first scene streams in and gets its choices" do
    fake = FakeChat.new(SCENE_RESPONSE, chunks: SCENE_RESPONSE.chars.each_slice(40).map(&:join))

    stub_llm(fake) do
      assert_turbo_stream_broadcasts @game_session do
        narrate
      end
    end

    scene = @game_session.scenes.sole
    assert scene.choosing?
    assert_equal "The Old Inn", scene.title
    assert_includes scene.narration, "Rain hammers the inn's"
    assert_not_includes scene.narration, "```"

    assert_equal 3, scene.choices.count
    assert_equal(-1, scene.choices.find_by(stat: "intelligence").modifier)
    assert_equal 3, scene.choices.find_by(stat: "strength").modifier
    assert_equal 1, scene.choices.find_by(stat: "wisdom").modifier

    call = @game_session.llm_calls.sole
    assert_equal "scene", call.purpose
    model = RubyLLM.models.find(call.model)
    assert_equal (1000 * model.input_price_per_million + 500 * model.output_price_per_million).round,
      call.cost_in_microdollars
    assert_operator call.cost_in_microdollars, :>, 0
  end

  test "the stage refreshes before narration streams into it" do
    fake = FakeChat.new(SCENE_RESPONSE, chunks: SCENE_RESPONSE.chars.each_slice(40).map(&:join))

    streams = stub_llm(fake) do
      capture_turbo_stream_broadcasts(@game_session) { narrate }
    end

    assert_equal "refresh", streams.first["action"]
    assert_operator streams.index { |stream| stream["target"] == "scene_narration" },
      :>, 0, "narration streamed before the stage was on screen"
    assert_equal "refresh", streams.last["action"], "the choices arrive with a final refresh"
  end

  test "every narration stream carries the whole text so far" do
    fake = FakeChat.new(SCENE_RESPONSE, chunks: SCENE_RESPONSE.chars.each_slice(40).map(&:join))

    streams = stub_llm(fake) do
      capture_turbo_stream_broadcasts(@game_session) { narrate }
    end

    narrations = streams.select { |stream| stream["target"] == "scene_narration" }
    assert_equal [ "update" ], narrations.map { |stream| stream["action"] }.uniq,
      "a morph refresh mid-stream would drop appended chunks; updates are idempotent"
    assert_equal @game_session.scenes.sole.narration, narrations.last.at("template").text
  end

  test "the outcome is written by its own call, without touching the story" do
    roll = play_first_scene
    assert_nil roll.resolution

    resolve roll

    assert_equal "The drawer opens, but you cut your hand.", roll.reload.resolution
    assert_equal 31 - 4, characters(:ilker_hero).reload.hp
    assert_equal 1, @game_session.scenes.count, "the outcome call must not write a scene"
    assert_equal "outcome", @game_session.llm_calls.outcome.sole.purpose
  end

  test "resolving a roll puts the outcome on screen" do
    roll = play_first_scene

    streams = capture_turbo_stream_broadcasts(@game_session) { resolve roll }

    assert_equal "refresh", streams.sole["action"], "the spinning die never stops without a refresh"
  end

  test "the next scene is not written until the player continues" do
    roll = play_first_scene
    resolve roll

    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    assert_equal 1, @game_session.scenes.count, "the narrator must idle while the outcome is unread"

    roll.acknowledge
    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }

    assert_equal 2, @game_session.scenes.count
    assert_equal "The Stable", @game_session.current_scene.title
    assert @game_session.current_scene.choosing?
  end

  test "outcome effects reach the inventory and the statuses" do
    character = characters(:ilker_hero)
    character.status_effects.create! name: "Dragging Leg", modifier: -1, expires_when: "until it eases"
    roll = play_first_scene

    fake = FakeChat.new(%({"resolution": "You find a salve in the chest, but you come out soaked.",
      "effects": {"hp": -2,
        "items_gained": [{"name": "Yellow salve", "kind": "instant", "description": "", "hp": 5, "uses": 1}],
        "items_lost": ["Inn ledger"],
        "statuses_gained": [{"name": "Soaked Through", "modifier": -2, "turns": 2, "expires_when": ""}],
        "statuses_lost": ["Dragging Leg"]}}))
    stub_llm(fake) { roll.narrate }

    assert_equal 31 - 2, character.reload.hp
    assert character.items.usable.exists?(name: "Yellow salve")
    assert_not character.items.exists?(name: "Inn ledger")
    assert_equal 2, character.status_effects.find_by!(name: "Soaked Through").turns_left
    assert_not character.status_effects.exists?(name: "Dragging Leg")
    assert_equal [ "Yellow salve" ], roll.reload.items_gained.pluck("name")
    assert_equal [ "Soaked Through" ], roll.statuses_gained.pluck("name")
  end

  test "a positive status is earned only by a natural twenty" do
    stub_llm(FakeChat.new(SCENE_RESPONSE)) { narrate }
    boon = %({"resolution": "The door opens.", "effects": {"hp": 0,
      "statuses_gained": [{"name": "Sure Grip", "modifier": 2, "turns": 2, "expires_when": ""}]}})

    roll = roll_with(value: 19)
    stub_llm(FakeChat.new(boon)) { roll.narrate }
    assert_empty characters(:ilker_hero).status_effects, "a brilliant success must not stack a bonus"
    assert_empty roll.reload.statuses_gained

    roll.acknowledge
    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    roll = roll_with(value: 20)
    stub_llm(FakeChat.new(boon)) { roll.narrate }
    assert characters(:ilker_hero).status_effects.exists?(name: "Sure Grip")
  end

  test "a resolution may replace an item it takes away" do
    roll = play_first_scene

    fake = FakeChat.new(%({"resolution": "Your flask breaks, but you find another in the wreckage.",
      "effects": {"hp": 0,
        "items_gained": [{"name": "Healing potion", "kind": "instant", "description": "", "hp": 6, "uses": 1}],
        "items_lost": ["Healing potion"]}}))
    stub_llm(fake) { roll.narrate }

    potions = characters(:ilker_hero).items.usable.where(name: "Healing potion")
    assert_equal 6, potions.sole.hp_effect, "the lost copy goes first so the replacement survives"
  end

  test "a granted item and status arrive normalized" do
    roll = play_first_scene

    fake = FakeChat.new(%({"resolution": "You find a salve in the chest, but you come out soaked.",
      "effects": {"hp": 0,
        "items_gained": [{"name": "Yellow salve", "kind": "instant", "description": "", "hp": 5, "uses": 0}],
        "statuses_gained": [{"name": "Soaked Through", "modifier": -5, "turns": 0, "expires_when": ""}]}}))
    stub_llm(fake) { roll.narrate }

    ointment = characters(:ilker_hero).items.find_by!(name: "Yellow salve")
    assert_equal 1, ointment.uses_left, "uses must be at least 1 or the item arrives dead"
    assert_equal 5, ointment.hp_effect

    soaked = characters(:ilker_hero).status_effects.find_by!(name: "Soaked Through")
    assert_equal(-2, soaked.modifier, "narrator modifiers are clamped to the dice range")
    assert_equal 2, soaked.turns_left, "an open-ended status would never wear off"
    assert_nil soaked.expires_when
    assert_equal(-2, roll.reload.statuses_gained.sole["modifier"], "the roll keeps the effects as applied")
  end

  test "an outcome granting an item of unknown kind is malformed" do
    roll = play_first_scene

    assert_no_difference -> { Item.count } do
      stub_llm(FakeChat.new(%({"resolution": "You find something.",
        "effects": {"hp": 0, "items_gained": [{"name": "Old charm", "kind": "relic"}]}}))) do
        assert_raises(Narrator::MalformedResponse) { roll.narrate }
      end
    end

    assert_nil roll.reload.resolution
  end

  test "an outcome granting a nameless item is malformed" do
    roll = play_first_scene

    assert_no_difference -> { Item.count } do
      stub_llm(FakeChat.new(%({"resolution": "You find something.",
        "effects": {"hp": 0, "items_gained": [{"name": "", "kind": "instant"}]}}))) do
        assert_raises(Narrator::MalformedResponse) { roll.narrate }
      end
    end

    assert_nil roll.reload.resolution
  end

  test "the narrator sees the inventory, the statuses and what was used" do
    characters(:ilker_hero).status_effects.create! name: "Sure Grip", modifier: 1, turns_left: 2
    roll = play_first_scene
    items(:healing_potion).use

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate }

    assert_includes fake.prompt, "INVENTORY:"
    assert_includes fake.prompt, "Longsword"
    assert_includes fake.prompt, "Inn ledger (quest item)"
    assert_not_includes fake.prompt, "Healing potion (instant", "a spent item must drop out of the inventory"
    assert_includes fake.prompt, "STATUS EFFECTS: Sure Grip (+1 to rolls, 2 turns)"
    assert_includes fake.prompt, "ITEM USED: Healing potion (+7 health)"
  end

  test "a used item is settled by the outcome and not raised again by the next scene" do
    roll = play_first_scene
    items(:healing_potion).use
    resolve roll
    roll.acknowledge

    scene_call = FakeChat.new(SECOND_SCENE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_not_includes scene_call.prompt, "ITEM USED"
  end

  test "statuses weigh on the roll and wear off with it" do
    character = characters(:ilker_hero)
    character.status_effects.create! name: "Soaked Through", modifier: -2, turns_left: 1

    stub_llm(FakeChat.new(SCENE_RESPONSE)) { narrate }
    scene = @game_session.current_scene
    choice = scene.choices.find_by!(stat: "strength")
    choice.choose
    roll = scene.roll_dice(by: scene.active_player)

    assert_equal(-2, roll.status_modifier)
    assert_equal roll.value + 3 - 2, roll.total
    assert_equal roll.total >= roll.target, roll.success?

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate }

    assert_includes fake.prompt, "-2 (status)"
    assert_empty character.status_effects.reload, "a one-turn status must not outlive its roll"
  end

  test "the outcome prompt carries the grade of the roll" do
    stub_llm(FakeChat.new(SCENE_RESPONSE)) { narrate }
    roll = roll_with(value: 20)

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate }

    assert_includes fake.prompt, "CRITICAL SUCCESS (natural 20"
  end

  test "a deep miss reaches the narrator with its distance" do
    stub_llm(FakeChat.new(SCENE_RESPONSE)) { narrate }
    roll = roll_with(value: 2)

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate }

    assert_includes fake.prompt, "HEAVY FAILURE (9 under the target)"
  end

  test "a scene reusing a stat across choices is malformed" do
    doubled = SCENE_RESPONSE.sub('"stat": "intelligence"', '"stat": "strength"')

    stub_llm(FakeChat.new(doubled)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert @game_session.scenes.sole.narrating?
  end

  test "a choice without a label is malformed" do
    unlabeled = SCENE_RESPONSE.sub('"label": "Force the drawer open", ', "")

    stub_llm(FakeChat.new(unlabeled)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert @game_session.scenes.sole.narrating?
    assert_empty @game_session.scenes.sole.choices
  end

  test "the story bible is written before the first scene" do
    @game_session.update! story_bible: nil
    plan_call = FakeChat.new(PLAN_RESPONSE)
    scene_call = FakeChat.new(SCENE_RESPONSE)

    stub_llm(plan_call, scene_call) { narrate }

    assert_includes plan_call.prompt, "SCENE COUNT: 7"
    assert_includes plan_call.prompt, "Warrior"
    assert_equal "Nail Aral", @game_session.reload.story_bible.dig("antagonist", "name")
    assert_equal %w[plan scene], @game_session.llm_calls.order(:id).pluck(:purpose)
    assert @game_session.current_scene.choosing?
  end

  test "a bible that never arrives leaves the first scene unwritten" do
    @game_session.update! story_bible: nil

    stub_llm(FakeChat.new("No bible.")) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert_nil @game_session.reload.story_bible
    assert @game_session.scenes.sole.narrating?
    assert_nil @game_session.scenes.sole.title
  end

  test "a written bible is not written twice" do
    scene_call = FakeChat.new(SCENE_RESPONSE)

    stub_llm(scene_call) { narrate }

    assert_equal %w[scene], @game_session.llm_calls.pluck(:purpose)
    assert_includes scene_call.prompt, "STORY BIBLE"
    assert_includes scene_call.prompt, "Nail Aral"
    assert_includes scene_call.prompt, "BEAT: A mule with a cut strap comes back to the square."
    assert_includes scene_call.prompt, "OPENING:"
  end

  test "the whole story so far reaches the narrator unabridged" do
    play_and_continue

    3.times do
      stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
      roll = choose_and_roll(@game_session.current_scene)
      resolve roll
      roll.acknowledge
    end

    scene_call = FakeChat.new(SECOND_SCENE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_includes scene_call.prompt, "[1] The Old Inn @ Whitebend"
    assert_includes scene_call.prompt, "[4] The Stable @ Whitebend"
    assert_includes scene_call.prompt, "The drawer opens, but you cut your hand."
    assert_includes scene_call.prompt, "BEAT: The crack in the bridge footing comes into view."
    assert_equal 4, scene_call.prompt.scan("→ Choice:").size
  end

  test "the surprise adventure takes its name from the bible" do
    @game_session.update! quest: nil
    assert_equal "The Lost Caravan", @game_session.title

    @game_session.update! story_bible: nil
    assert_equal "Surprise adventure", @game_session.title
  end

  test "the finale is told the tally of the dice" do
    play_and_continue

    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    roll = roll_with(value: 2)
    resolve roll
    roll.acknowledge
    @game_session.update! length: "short"
    @game_session.current_scene.update! position: @game_session.scene_budget

    scene_call = FakeChat.new(FINALE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_match(/ROLL TALLY: \d+ successes, \d+ failures\. The climax roll was HEAVY FAILURE/, scene_call.prompt)
    assert @game_session.reload.finished?
  end

  test "the easy and hard stats of recent scenes are steered away from" do
    play_and_continue

    scene_call = FakeChat.new(SECOND_SCENE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_includes scene_call.prompt, %(VARIETY: The choices in the last scenes were: "Read the dusty ledger", "Force the drawer open", "Listen at the stable in silence".)
    assert_includes scene_call.prompt, "The easy choice was on Intelligence and the hard choice on —"
  end

  test "a downed character forces the defeat finale" do
    characters(:ilker_hero).update! hp: 0

    scene_call = FakeChat.new(FINALE_RESPONSE.sub('"outcome": "victory"', '"outcome": "defeat"'))
    stub_llm(scene_call) { narrate }

    assert_includes scene_call.prompt, "THE CHARACTER HAS COLLAPSED"
    assert @game_session.reload.finished?
    assert @game_session.outcome_defeat?
  end

  test "a downed character is denied another scene and a victory alike" do
    characters(:ilker_hero).update! hp: 0

    stub_llm(FakeChat.new(SCENE_RESPONSE)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end
    stub_llm(FakeChat.new(FINALE_RESPONSE)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert @game_session.scenes.sole.narrating?
    assert_not @game_session.reload.finished?
  end

  test "the missing healing item is flagged once the need is real" do
    characters(:ilker_hero).update! hp: 12
    play_and_continue
    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    items(:healing_potion).use
    roll = choose_and_roll(@game_session.current_scene)

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate }

    assert_includes fake.prompt, "MISSING:"
  end

  test "the healing hint rests while the character stands strong" do
    play_and_continue
    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    items(:healing_potion).use
    roll = choose_and_roll(@game_session.current_scene)

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate }

    assert_not_includes fake.prompt, "MISSING:",
      "a healthy character early in the story must not spawn potions"
  end

  test "the healing hint pauses right after a find" do
    characters(:ilker_hero).update! hp: 5
    items(:healing_potion).use
    roll = play_first_scene

    fake = FakeChat.new(%({"resolution": "You find a charm on the shelf.",
      "effects": {"hp": 0, "items_gained": [{"name": "Old charm", "kind": "quest", "description": "", "hp": 0, "uses": 0}]}}))
    stub_llm(fake) { roll.narrate }
    roll.acknowledge
    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    next_roll = choose_and_roll(@game_session.current_scene)

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { next_roll.narrate }

    assert_not_includes fake.prompt, "MISSING:",
      "back-to-back finds cheapen the loot"
  end

  test "no healing hint while a potion is still carried" do
    play_and_continue
    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    roll = choose_and_roll(@game_session.current_scene)

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate }

    assert_not_includes fake.prompt, "MISSING:"
  end

  test "the world adapts when one stat is spammed" do
    stub_llm(FakeChat.new(SCENE_RESPONSE)) { narrate }

    2.times do
      roll = roll_strength(@game_session.current_scene)
      resolve roll
      roll.acknowledge
      stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    end

    roll = roll_strength(@game_session.current_scene)
    resolve roll
    roll.acknowledge

    scene_call = FakeChat.new(SECOND_SCENE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_match(/REPETITION:.*Strength/, scene_call.prompt)
  end

  test "a badly wounded character earns a breather in the scene prompt" do
    characters(:ilker_hero).update! hp: 9
    play_and_continue

    scene_call = FakeChat.new(SECOND_SCENE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_includes scene_call.prompt, "BADLY WOUNDED"
  end

  test "a roll is never resolved twice" do
    roll = play_first_scene

    resolve roll
    resolve roll

    assert_equal 31 - 4, characters(:ilker_hero).reload.hp
    assert_equal 1, @game_session.llm_calls.outcome.count
  end

  test "nothing is owed while the player is choosing" do
    stub_llm(FakeChat.new(SCENE_RESPONSE)) do
      2.times { narrate }
    end

    assert_equal 1, @game_session.scenes.count
  end

  test "a half-written scene is finished on the next attempt" do
    stub_llm(FakeChat.new("Prose arrived but no structure."), FakeChat.new(SCENE_RESPONSE)) do
      assert_raises Narrator::MalformedResponse do
        narrate
      end
      assert @game_session.scenes.sole.narrating?

      narrate
    end

    scene = @game_session.scenes.sole
    assert scene.choosing?
    assert_equal "The Old Inn", scene.title
    assert_equal 3, scene.choices.count
  end

  test "an outcome with a blank resolution is malformed" do
    roll = play_first_scene

    stub_llm(FakeChat.new(%({"resolution": "", "effects": {"hp": -4}}))) do
      assert_raises Narrator::MalformedResponse do
        roll.narrate
      end
    end

    assert_nil roll.reload.resolution
  end

  test "a finale closes the game" do
    play_and_continue

    stub_llm(FakeChat.new(FINALE_RESPONSE)) { narrate }

    finale = @game_session.current_scene
    assert finale.finale?
    assert finale.played?
    assert_empty finale.choices
    assert @game_session.reload.finished?
    assert @game_session.outcome_victory?
    assert @game_session.ended_at.present?
  end

  test "a finale without a known outcome is malformed" do
    play_and_continue

    stub_llm(FakeChat.new(FINALE_RESPONSE.sub('"outcome": "victory"', '"outcome": "belirsiz"'))) do
      assert_raises Narrator::MalformedResponse do
        narrate
      end
    end

    assert_not @game_session.reload.finished?
  end

  test "a broken structure block is malformed" do
    stub_llm(FakeChat.new("Prose arrived but no structure. ```json {broken``` ")) do
      assert_raises Narrator::MalformedResponse do
        narrate
      end
    end
  end

  test "the final scene is demanded when the budget is spent" do
    @game_session.update! length: "short"
    @game_session.scenes.sole.update! state: :played, title: "Scene 1", narration: "Events."
    (2...@game_session.scene_budget).each do |position|
      @game_session.scenes.create! position: position, active_player: players(:ilker_solo_host),
        state: :played, title: "Scene #{position}", narration: "Events."
    end
    roll = build_roll
    resolve roll
    roll.acknowledge

    scene_call = FakeChat.new(FINALE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_includes scene_call.prompt, "FINALE"
    assert @game_session.reload.finished?
  end

  private
    def narrate
      Narrator.new(@game_session).narrate_scene(@game_session.current_scene)
    end

    def resolve(roll)
      stub_llm(FakeChat.new(OUTCOME_RESPONSE)) { roll.narrate }
    end

    def play_first_scene
      stub_llm(FakeChat.new(SCENE_RESPONSE)) { narrate }
      choose_and_roll @game_session.current_scene
    end

    def play_and_continue
      roll = play_first_scene
      resolve roll
      roll.acknowledge
      roll
    end

    def choose_and_roll(scene)
      choice = scene.choices.first
      choice.choose
      scene.roll_dice(by: scene.active_player)
    end

    def roll_strength(scene)
      choice = scene.choices.find_by!(stat: "strength")
      choice.choose
      scene.roll_dice(by: scene.active_player)
    end

    def roll_with(value:)
      scene = @game_session.current_scene
      choice = scene.choices.find_by!(stat: "strength")
      choice.choose
      scene.played!
      choice.create_roll! player: scene.active_player, value: value, status_modifier: 0
    end

    def build_roll
      scene = @game_session.scenes.create! position: @game_session.scene_budget + 10,
        active_player: players(:ilker_solo_host), state: :choosing, title: "Ara"
      choice = scene.choices.create! label: "Press on", stat: "strength", modifier: 3,
        target: 12
      choice.choose
      scene.roll_dice(by: players(:ilker_solo_host))
    end
end
