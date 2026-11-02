require "test_helper"
require "turbo/broadcastable/test_helper"

class NarratorTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    @game_session = game_sessions(:ilker_solo)
    @game_session.advance
  end

  test "the first scene streams in and gets its choices" do
    fake = FakeReply.new(SCENE_RESPONSE, chunks: SCENE_RESPONSE.chars.each_slice(40).map(&:join))

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
    assert_equal (1000 * model.price(:input) + 500 * model.price(:output)).round,
      call.cost_in_microdollars
    assert_operator call.cost_in_microdollars, :>, 0
  end

  test "a scene written without its fence still gets its choices" do
    unfenced = SCENE_RESPONSE.delete("`").sub("json\n", "").sub("The dust lies thick", "Dust lies thick, {in} braces")
    fake = FakeReply.new(unfenced, chunks: unfenced.chars.each_slice(40).map(&:join))

    stub_llm(fake) { narrate }

    scene = @game_session.scenes.sole
    assert scene.choosing?
    assert_equal "The Old Inn", scene.title
    assert_equal "Dust lies thick, {in} braces", scene.choices.find_by(stat: "intelligence").difficulty_reason
    assert scene.narration.start_with?("Rain hammers")
  end

  test "the stage refreshes before narration streams into it" do
    fake = FakeReply.new(SCENE_RESPONSE, chunks: SCENE_RESPONSE.chars.each_slice(40).map(&:join))

    streams = stub_llm(fake) do
      capture_turbo_stream_broadcasts(@game_session) { narrate }
    end

    assert_equal "refresh", streams.first["action"]
    assert_operator streams.index { |stream| stream["target"] == "scene_narration" },
      :>, 0, "narration streamed before the stage was on screen"
    assert_equal "refresh", streams.last["action"], "the choices arrive with a final refresh"
  end

  test "every narration stream carries the whole text so far" do
    fake = FakeReply.new(SCENE_RESPONSE, chunks: SCENE_RESPONSE.chars.each_slice(40).map(&:join))

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

    stub_llm(FakeReply.new(SECOND_SCENE_RESPONSE)) { narrate }
    assert_equal 1, @game_session.scenes.count, "the narrator must idle while the outcome is unread"

    roll.acknowledge
    stub_llm(FakeReply.new(SECOND_SCENE_RESPONSE)) { narrate }

    assert_equal 2, @game_session.scenes.count
    assert_equal "The Stable", @game_session.current_scene.title
    assert @game_session.current_scene.choosing?
  end

  test "outcome effects reach the inventory and the statuses" do
    character = characters(:ilker_hero)
    character.status_effects.create! name: "Dragging Leg", modifier: -1, expires_when: "until it eases"
    roll = play_first_scene

    fake = FakeReply.new(%({"resolution": "You find a salve in the chest, but you come out soaked.",
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
    stub_llm(FakeReply.new(SCENE_RESPONSE)) { narrate }
    boon = %({"resolution": "The door opens.", "effects": {"hp": 0,
      "statuses_gained": [{"name": "Sure Grip", "modifier": 2, "turns": 2, "expires_when": ""}]}})

    roll = roll_with(value: 19)
    stub_llm(FakeReply.new(boon)) { roll.narrate }
    assert_empty characters(:ilker_hero).status_effects, "a brilliant success must not stack a bonus"
    assert_empty roll.reload.statuses_gained

    roll.acknowledge
    stub_llm(FakeReply.new(SECOND_SCENE_RESPONSE)) { narrate }
    roll = roll_with(value: 20)
    stub_llm(FakeReply.new(boon)) { roll.narrate }
    assert characters(:ilker_hero).status_effects.exists?(name: "Sure Grip")
  end

  test "a resolution may replace an item it takes away" do
    roll = play_first_scene

    fake = FakeReply.new(%({"resolution": "Your flask breaks, but you find another in the wreckage.",
      "effects": {"hp": 0,
        "items_gained": [{"name": "Healing potion", "kind": "instant", "description": "", "hp": 6, "uses": 1}],
        "items_lost": ["Healing potion"]}}))
    stub_llm(fake) { roll.narrate }

    potions = characters(:ilker_hero).items.usable.where(name: "Healing potion")
    assert_equal 6, potions.sole.hp_effect, "the lost copy goes first so the replacement survives"
  end

  test "a granted item and status arrive normalized" do
    roll = play_first_scene

    fake = FakeReply.new(%({"resolution": "You find a salve in the chest, but you come out soaked.",
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
      stub_llm(FakeReply.new(%({"resolution": "You find something.",
        "effects": {"hp": 0, "items_gained": [{"name": "Old charm", "kind": "relic"}]}}))) do
        assert_raises(Narrator::MalformedResponse) { roll.narrate }
      end
    end

    assert_nil roll.reload.resolution
  end

  test "an outcome granting a nameless item is malformed" do
    roll = play_first_scene

    assert_no_difference -> { Item.count } do
      stub_llm(FakeReply.new(%({"resolution": "You find something.",
        "effects": {"hp": 0, "items_gained": [{"name": "", "kind": "instant"}]}}))) do
        assert_raises(Narrator::MalformedResponse) { roll.narrate }
      end
    end

    assert_nil roll.reload.resolution
  end

  test "the brief carries the party, and a roll carries what was used" do
    roll = play_first_scene
    items(:healing_potion).use

    fake = FakeReply.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate }

    assert_includes fake.instructions, "Longsword"
    assert_includes fake.instructions, "Inn ledger (quest item)"
    assert_includes fake.prompt, "used Healing potion (+7 health)"
    assert_includes fake.prompt, "Ilker has 31/31 health. Resolve it."
  end

  test "a used item is settled by the outcome and not raised again by the next scene" do
    roll = play_first_scene
    items(:healing_potion).use
    resolve roll
    roll.acknowledge

    scene_call = FakeReply.new(SECOND_SCENE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_equal "Scene 2 of 7. Write the next scene.", scene_call.prompt
  end

  test "statuses weigh on the roll and wear off with it" do
    character = characters(:ilker_hero)
    character.status_effects.create! name: "Soaked Through", modifier: -2, turns_left: 1

    stub_llm(FakeReply.new(SCENE_RESPONSE)) { narrate }
    scene = @game_session.current_scene
    choice = scene.choices.find_by!(stat: "strength")
    choice.choose
    roll = scene.roll_dice(by: scene.active_player)

    assert_equal(-2, roll.status_modifier)
    assert_equal roll.value + 3 - 2, roll.total
    assert_equal roll.total >= roll.target, roll.success?

    fake = FakeReply.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate }

    assert_includes fake.prompt, "-2 (status)"
    assert_empty character.status_effects.reload, "a one-turn status must not outlive its roll"
  end

  test "the outcome prompt carries the grade of the roll" do
    stub_llm(FakeReply.new(SCENE_RESPONSE)) { narrate }
    roll = roll_with(value: 20)

    fake = FakeReply.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate }

    assert_includes fake.prompt, "rolled 20 +3 = 23 against 14: CRITICAL SUCCESS (natural 20)."
  end

  test "a deep miss reaches the narrator with its distance" do
    stub_llm(FakeReply.new(SCENE_RESPONSE)) { narrate }
    roll = roll_with(value: 2)

    fake = FakeReply.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate }

    assert_includes fake.prompt, "HEAVY FAILURE (9 under the target)"
  end

  test "a scene reusing a stat across choices is malformed" do
    doubled = SCENE_RESPONSE.sub('"stat": "intelligence"', '"stat": "strength"')

    stub_llm(FakeReply.new(doubled)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert @game_session.scenes.sole.narrating?
  end

  test "a choice without a label is malformed" do
    unlabeled = SCENE_RESPONSE.sub('"label": "Force the drawer open", ', "")

    stub_llm(FakeReply.new(unlabeled)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert @game_session.scenes.sole.narrating?
    assert_empty @game_session.scenes.sole.choices
  end

  test "the brief opens one chat for the whole game" do
    first = FakeReply.new(SCENE_RESPONSE)
    stub_llm(first) { narrate }

    assert_equal [ :system, :user ], first.messages.map(&:role)
    assert_includes first.instructions, "Length: 7 scenes"
    assert_includes first.instructions, "Quest: The caravan carrying Whitebend's winter salt"
    assert_includes first.instructions, "Warrior"
    assert_equal "Scene 1 of 7. Write the first scene.", first.prompt

    roll = with_die(2) { choose_and_roll @game_session.current_scene }
    outcome = FakeReply.new(OUTCOME_RESPONSE)
    stub_llm(outcome) { roll.narrate }
    roll.acknowledge
    second = FakeReply.new(SECOND_SCENE_RESPONSE)
    stub_llm(second) { narrate }

    assert_equal 1, Chat.where(game_session: @game_session).count
    assert_equal first.instructions, second.instructions, "the brief never changes, so the cache holds"
    assert_equal %i[system user assistant user assistant user], second.messages.map(&:role)
    assert_includes second.messages[2].content, "Rain hammers the inn's roof tiles"
    assert_equal "The drawer opens, but you cut your hand.", JSON.parse(second.messages[4].content)["resolution"]
  end

  test "the story so far is the conversation itself" do
    play_and_continue

    3.times do
      stub_llm(FakeReply.new(SECOND_SCENE_RESPONSE)) { narrate }
      roll = choose_and_roll(@game_session.current_scene)
      resolve roll
      roll.acknowledge
    end

    scene_call = FakeReply.new(SECOND_SCENE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_equal 1 + 2 * 8 + 1, scene_call.messages.size
    assert_equal "Scene 5 of 7. Write the next scene.", scene_call.prompt
    assert_equal 1, scene_call.messages.count { |message| message.role == :system }
  end

  test "a turn the provider never answered is answered on the next attempt" do
    stub_llm(FakeReply.failing(RubyLLM::ServerError.new("overloaded"))) do
      assert_raises(RubyLLM::ServerError) { narrate }
    end

    retry_call = FakeReply.new(SCENE_RESPONSE)
    stub_llm(retry_call) { narrate }

    assert @game_session.current_scene.choosing?
    assert_equal %i[system user], retry_call.messages.map(&:role), "the turn is not asked twice"
  end

  test "a Turkish game is written in Turkish from an English briefing" do
    @game_session.update! locale: "tr"
    scene_call = FakeReply.new(SCENE_RESPONSE)

    I18n.with_locale(:tr) { stub_llm(scene_call) { narrate } }

    assert_includes scene_call.instructions, "Everything the players see is written in Turkish"
    assert_includes scene_call.instructions, "Akçabük", "the quest frame carries the Turkish place names"
    assert_includes scene_call.instructions, "Warrior", "the brief stays in English whatever the page speaks"
    assert_includes scene_call.instructions, "Strength 16"
    assert_equal "Scene 1 of 7. Write the first scene.", scene_call.prompt
  end

  test "an English game is written in English" do
    scene_call = FakeReply.new(SCENE_RESPONSE)

    stub_llm(scene_call) { narrate }

    assert_includes scene_call.instructions, "Everything the players see is written in English"
  end

  test "the surprise adventure takes its name from the first scene" do
    @game_session.update! quest: nil
    assert_equal "Surprise adventure", @game_session.title

    stub_llm(FakeReply.new(SCENE_RESPONSE)) do
      error = assert_raises(Narrator::MalformedResponse) { narrate }
      assert_equal "the first scene must name the adventure", error.message
    end

    named = FakeReply.new(SCENE_RESPONSE.sub('{"title"', '{"adventure": "Blizzard Salt", "title"'))
    stub_llm(named) { narrate }

    assert_includes named.instructions, "names the adventure"
    assert_equal "Blizzard Salt", @game_session.reload.title
    assert_equal "The Old Inn", @game_session.current_scene.title
  end

  test "a ready-made quest keeps its own name" do
    scene_call = FakeReply.new(SCENE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_not_includes scene_call.instructions, "names the adventure"
    assert_equal "The Lost Caravan", @game_session.reload.title
  end

  test "a downed character forces the defeat finale" do
    characters(:ilker_hero).update! hp: 0

    scene_call = FakeReply.new(FINALE_RESPONSE.sub('"outcome": "victory"', '"outcome": "defeat"'))
    stub_llm(scene_call) { narrate }

    assert_equal "Ilker has collapsed, their health spent. Scene 1 of 7 is the finale: close the story in defeat.", scene_call.prompt
    assert @game_session.reload.finished?
    assert @game_session.outcome_defeat?
  end

  test "a downed character is denied another scene and a victory alike" do
    characters(:ilker_hero).update! hp: 0

    stub_llm(FakeReply.new(SCENE_RESPONSE)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end
    stub_llm(FakeReply.new(FINALE_RESPONSE)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert @game_session.scenes.sole.narrating?
    assert_not @game_session.reload.finished?
  end

  test "a roll is never resolved twice" do
    roll = play_first_scene

    resolve roll
    resolve roll

    assert_equal 31 - 4, characters(:ilker_hero).reload.hp
    assert_equal 1, @game_session.llm_calls.outcome.count
  end

  test "nothing is owed while the player is choosing" do
    stub_llm(FakeReply.new(SCENE_RESPONSE)) do
      2.times { narrate }
    end

    assert_equal 1, @game_session.scenes.count
  end

  test "a half-written scene is finished on the next attempt" do
    broken = Array.new(Narrator::REWRITES + 1) { FakeReply.new("Prose arrived but no structure.") }

    stub_llm(broken, FakeReply.new(SCENE_RESPONSE)) do
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

    stub_llm(FakeReply.new(%({"resolution": "", "effects": {"hp": -4}}))) do
      assert_raises Narrator::MalformedResponse do
        roll.narrate
      end
    end

    assert_nil roll.reload.resolution
  end

  test "a finale closes the game" do
    play_and_continue

    stub_llm(FakeReply.new(FINALE_RESPONSE)) { narrate }

    finale = @game_session.current_scene
    assert finale.finale?
    assert finale.played?
    assert_empty finale.choices
    assert @game_session.reload.finished?
    assert @game_session.outcome_victory?
    assert @game_session.ended_at.present?
  end

  test "a finale takes the stage before its closing words stream in" do
    play_and_continue
    finale = @game_session.current_scene
    staged = []

    fake = FakeReply.split_at_structure(FINALE_RESPONSE) do
      staged << [ finale.reload.finale?, @game_session.reload.outcome, @game_session.finished? ]
    end
    stub_llm(fake) { narrate }

    assert_equal [ true, "victory", false ], staged.first,
      "the finale screen must be up before the closing words stream in"
    assert @game_session.reload.finished?
  end

  test "a finale without a known outcome is malformed" do
    play_and_continue

    stub_llm(FakeReply.new(FINALE_RESPONSE.sub('"outcome": "victory"', '"outcome": "belirsiz"'))) do
      assert_raises Narrator::MalformedResponse do
        narrate
      end
    end

    assert_not @game_session.reload.finished?
  end

  test "a broken structure block is malformed" do
    stub_llm(FakeReply.new("Prose arrived but no structure. ```json {broken``` ")) do
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

    scene_call = FakeReply.new(FINALE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_includes scene_call.prompt, "the finale: close the story with victory or defeat."
    assert @game_session.reload.finished?
  end

  test "a reply that breaks a rule is rewritten with the reason" do
    out_of_range = SCENE_RESPONSE.sub('"difficulty": 14', '"difficulty": 25')
    broken = FakeReply.new(out_of_range)
    rewrite = FakeReply.new(SCENE_RESPONSE)

    stub_llm(broken, rewrite) { narrate }

    assert @game_session.scenes.sole.choosing?
    assert_equal "Scene 1 of 7. Write the first scene.", broken.prompt
    assert_equal "Your reply was rejected: difficulty 25 is outside 8-19. Write the whole reply again.", rewrite.prompt
    assert_equal %i[system user assistant user], rewrite.messages.map(&:role)
  end

  test "a scene that does not fit the screen is rewritten until the narrator gives up" do
    long = "word " * 20
    { "the narration" => SCENE_RESPONSE + "\n#{"Snow falls. " * 50}",
      "the choice label" => SCENE_RESPONSE.sub('"label": "Force the drawer open"', %("label": "#{long}")),
      "the difficulty reason" => SCENE_RESPONSE.sub('"The lock is old"', %("#{long}")) }.each do |part, reply|
      fake = FakeReply.new(reply)

      stub_llm(fake) do
        error = assert_raises(Narrator::MalformedResponse) { narrate }
        assert_match(/\A#{part} runs \d+ words, at most \d+ fit the screen: "/, error.message)
      end

      assert_includes fake.prompt, "rejected: #{part} runs"
      assert @game_session.scenes.sole.narrating?
    end
  end

  test "a title must fit beside the progress dots on one line" do
    @game_session.update! length: "long"

    stub_llm(FakeReply.new(SCENE_RESPONSE.sub('"title": "The Old Inn"', '"title": "The Old Coaching Inn"'))) do
      error = assert_raises(Narrator::MalformedResponse) { narrate }
      assert_equal 'the title "The Old Coaching Inn" runs 20 characters, at most 12 fit beside the progress dots', error.message
    end

    @game_session.update! length: "short"
    stub_llm(FakeReply.new(SCENE_RESPONSE.sub('"title": "The Old Inn"', '"title": "The Old Coaching Inn"'))) { narrate }
    assert_equal "The Old Coaching Inn", @game_session.scenes.sole.title
  end

  test "the last scene must be the finale" do
    @game_session.current_scene.update! position: @game_session.scene_budget

    stub_llm(FakeReply.new(SCENE_RESPONSE)) do
      error = assert_raises(Narrator::MalformedResponse) { narrate }
      assert_equal "scene 7 is the last one, so it must be the finale", error.message
    end

    assert_not @game_session.reload.finished?
  end

  test "health follows the grade of the roll" do
    stub_llm(FakeReply.new(SCENE_RESPONSE)) { narrate }
    roll = roll_with(value: 20)
    stub_llm(FakeReply.new(%({"resolution": "You fly through.", "effects": {"hp": -4}}))) { roll.narrate }
    assert_equal 0, roll.reload.hp_change, "a success does not hurt"

    roll.acknowledge
    stub_llm(FakeReply.new(SECOND_SCENE_RESPONSE)) { narrate }
    roll = roll_with(value: 2)
    stub_llm(FakeReply.new(%({"resolution": "You fall hard.", "effects": {"hp": -30}}))) { roll.narrate }
    assert_equal(-9, roll.reload.hp_change, "a heavy failure costs at most 9")
    assert_equal 31 - 9, characters(:ilker_hero).reload.hp
  end

  test "a resolution that does not fit the screen is rewritten" do
    roll = play_first_scene
    long = FakeReply.new(%({"resolution": "#{"The drawer sticks. " * 20}", "effects": {"hp": 0}}))

    stub_llm(long, FakeReply.new(OUTCOME_RESPONSE)) { roll.narrate }

    assert_equal "The drawer opens, but you cut your hand.", roll.reload.resolution
    assert_equal 2, @game_session.llm_calls.outcome.count
  end

  test "a character carries no more statuses than the limit" do
    character = characters(:ilker_hero)
    character.status_effects.create! name: "Bruised Ribs", modifier: -1, turns_left: 3
    character.status_effects.create! name: "Soaked Through", modifier: -1, turns_left: 3
    roll = play_first_scene

    stub_llm(FakeReply.new(%({"resolution": "You get burned.", "effects": {"hp": -2,
      "statuses_gained": [{"name": "Burned Palms", "modifier": -1, "turns": 9, "expires_when": ""}]}}))) do
      error = assert_raises(Narrator::MalformedResponse) { roll.narrate }
      assert_equal "the character would carry 3 statuses, at most 2", error.message
    end

    stub_llm(FakeReply.new(%({"resolution": "You get burned.", "effects": {"hp": -2,
      "statuses_gained": [{"name": "Burned Palms", "modifier": -1, "turns": 9, "expires_when": ""}],
      "statuses_lost": ["Soaked Through"]}}))) { roll.narrate }

    assert_equal 3, character.status_effects.find_by!(name: "Burned Palms").turns_left, "a status lasts 3 turns at most"
  end

  test "the understudy writes a scene at no cost" do
    stub_understudy(SCENE_RESPONSE) { narrate }

    scene = @game_session.scenes.sole
    assert scene.choosing?
    assert_equal "The Old Inn", scene.title
    assert scene.narration.start_with?("Rain hammers")
    assert_equal 3, scene.choices.count

    call = @game_session.llm_calls.sole
    assert_equal [ "understudy", 0 ], [ call.model, call.cost_in_microdollars ]
  end

  test "the understudy resolves a roll at no cost" do
    stub_understudy(SCENE_RESPONSE) { narrate }
    roll = with_die(2) { choose_and_roll @game_session.current_scene }

    stub_understudy(OUTCOME_RESPONSE) { roll.narrate }

    assert_equal "The drawer opens, but you cut your hand.", roll.reload.resolution
    assert_equal 0, @game_session.llm_calls.outcome.sole.cost_in_microdollars
  end

  private
    def narrate
      Narrator.new(@game_session).narrate_scene(@game_session.current_scene)
    end

    def resolve(roll)
      stub_llm(FakeReply.new(OUTCOME_RESPONSE)) { roll.narrate }
    end

    def play_first_scene
      stub_llm(FakeReply.new(SCENE_RESPONSE)) { narrate }
      with_die(2) { choose_and_roll @game_session.current_scene }
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
