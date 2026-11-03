require "test_helper"
require "turbo/broadcastable/test_helper"

class NarratorTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    @game_session = game_sessions(:ilker_solo)
    @game_session.advance
  end

  test "the first scene streams in and gets its choices" do
    stub_understudy(SCENE_RESPONSE) do
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
  end

  test "the narration streams in before the stage refreshes with the title and the choices" do
    streams = capture_turbo_stream_broadcasts(@game_session) do
      stub_understudy(SCENE_RESPONSE) { narrate }
    end

    assert_equal "scene_narration", streams.first["target"], "the first words reach the screen before any refresh"
    assert_equal "refresh", streams.last["action"], "the title and the choices arrive with a final refresh"
  end

  test "every narration stream carries the whole text so far and the scene is written once the reply is complete" do
    scene = @game_session.current_scene
    writes = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |event| writes << event.payload[:sql] if event.payload[:sql].start_with?('UPDATE "scenes"') }

    streams = capture_turbo_stream_broadcasts(@game_session) do
      stub_understudy(SCENE_RESPONSE) { narrate }
    ensure
      ActiveSupport::Notifications.unsubscribe subscriber
      end

      assert_equal 1, writes.size, "the narration is written once, when the reply is complete"
      assert_equal SCENE_RESPONSE.split("```").first.strip, scene.reload.narration

      narrations = streams.select { |stream| stream["target"] == "scene_narration" }.map { |stream| [ stream["action"], stream.at("template").text ] }
      assert_operator narrations.size, :>, 1
      assert_equal [ "update" ], narrations.map(&:first).uniq,
        "a morph refresh mid-stream would drop appended chunks; updates are idempotent"
      narrations.map(&:last).each_cons(2) { |earlier, later| assert later.start_with?(earlier.strip), "#{later.inspect} drops #{earlier.inspect}" }
      assert_equal scene.narration, narrations.last.last
    end

  test "the outcome is written by its own call, without touching the story" do
    roll = play_first_scene
    assert_nil roll.resolution

    resolve roll

    assert_equal "The drawer opens, but you cut your hand.", roll.reload.resolution
    assert_equal 31 - 4, characters(:ilker_hero).reload.hp
    assert_equal 1, @game_session.scenes.count, "the outcome call must not write a scene"
    assert_equal 2, @game_session.conversation.ruby_llm_usages.count
  end

  test "resolving a roll puts the outcome on screen" do
    roll = play_first_scene

    streams = capture_turbo_stream_broadcasts(@game_session) { resolve roll }

    assert_equal "refresh", streams.sole["action"], "the spinning die never stops without a refresh"
  end

  test "the next scene is not written until the player continues" do
    roll = play_first_scene
    resolve roll

    assert_empty stub_understudy(SECOND_SCENE_RESPONSE) { narrate }, "the narrator must idle while the outcome is unread"
    assert_equal 1, @game_session.scenes.count

    roll.acknowledge
    stub_understudy(SECOND_SCENE_RESPONSE) { narrate }

    assert_equal 2, @game_session.scenes.count
    assert_equal "The Stable", @game_session.current_scene.title
    assert @game_session.current_scene.choosing?
  end

  test "the brief carries the party, and a roll carries what was used" do
    roll = play_first_scene
    items(:healing_potion).use

    request = stub_understudy(OUTCOME_RESPONSE) { roll.narrate }.sole

    assert_includes request["system"], "Sets out with Longsword; Round shield."
    assert request["prompt"].end_with?(<<~CUE)


      Ilker chose "#{roll.choice.label}": die 2, modifier #{format("%+d", roll.modifier)}, statuses +0, total #{roll.total} against #{roll.target}. #{roll.grade_label}, margin #{format("%+d", roll.margin)}.
      Used since the scene began, already applied: Healing potion (+7 health).
      Ilker now: 31/31 health; carries Longsword, Inn ledger (quest item); no statuses.
    CUE
  end

  test "a used item is settled by the outcome and not raised again by the next scene" do
    roll = play_first_scene
    items(:healing_potion).use
    resolve roll
    roll.acknowledge

    request = stub_understudy(SECOND_SCENE_RESPONSE) { narrate }.sole

    assert request["prompt"].include?("\n\nScene 2 of 7, Ilker's turn. Raise the stakes: pay for what came before, and let the one who stands in the way act.\nIlker: ")
  end

  test "statuses weigh on the roll and wear off with it" do
    character = characters(:ilker_hero)
    character.status_effects.create! name: "Soaked Through", modifier: -2, turns_left: 1

    stub_understudy(SCENE_RESPONSE) { narrate }
    scene = @game_session.current_scene
    choice = scene.choices.find_by!(stat: "strength")
    choice.choose
    roll = scene.roll_dice(by: scene.active_player)

    assert_equal(-2, roll.status_modifier)
    assert_equal roll.value + 3 - 2, roll.total
    assert_equal roll.total >= roll.target, roll.success?

    request = stub_understudy(OUTCOME_RESPONSE) { roll.narrate }.sole

    assert_includes request["prompt"], "statuses -2, total #{roll.total}"
    assert_empty character.status_effects.reload, "a one-turn status must not outlive its roll"
  end

  test "a scene reusing a stat across choices is malformed" do
    doubled = SCENE_RESPONSE.sub('"stat": "intelligence"', '"stat": "strength"')

    stub_understudy(*rewrites_of(doubled)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert @game_session.scenes.sole.narrating?
  end

  test "a choice without a label is malformed" do
    unlabeled = SCENE_RESPONSE.sub('"label": "Force the drawer open", ', "")

    stub_understudy(*rewrites_of(unlabeled)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert @game_session.scenes.sole.narrating?
    assert_empty @game_session.scenes.sole.choices
  end

  test "the brief opens one conversation for the whole game" do
    first = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert_includes first["system"], "Length: 7 scenes"
    assert_includes first["system"], "Quest: The caravan carrying Whitebend's winter salt"
    assert_includes first["system"], "Warrior"
    assert_equal "Scene 1 of 7, Ilker's turn. Open the story in motion and decide the secret.\n#{sheet}", first["prompt"], "the first turn has no story before it"

    roll = with_die(2) { choose_and_roll @game_session.current_scene }
    stub_understudy(OUTCOME_RESPONSE) { roll.narrate }
    roll.acknowledge
    second = stub_understudy(SECOND_SCENE_RESPONSE) { narrate }.sole

    assert_equal 1, Narrator::Conversation.where(game_session: @game_session).count
    assert_equal first["system"], second["system"], "the brief never changes, so the cache holds"
    assert_equal %w[user assistant user assistant], second["prompt"].scan(/^<(user|assistant)>$/).flatten
    assert_includes second["prompt"], "Rain hammers the inn's roof tiles"
    assert_includes second["prompt"], "The drawer opens, but you cut your hand."
  end

  test "the story so far is the conversation itself" do
    play_and_continue

    3.times do
      stub_understudy(SECOND_SCENE_RESPONSE) { narrate }
      roll = choose_and_roll(@game_session.current_scene)
      resolve roll
      roll.acknowledge
    end

    request = stub_understudy(SECOND_SCENE_RESPONSE) { narrate }.sole

    assert_equal 2 * 8, request["prompt"].scan(/^<(user|assistant)>$/).size
    assert request["prompt"].include?("\n\nScene 5 of 7, Ilker's turn. Raise the stakes: pay for what came before, and let the one who stands in the way act.\nIlker: ")
  end

  test "a turn the provider never answered is answered on the next attempt" do
    stub_understudy(nil) do
      assert_raises(RubyLLM::ServerError) { narrate }
    end

    retry_call = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert @game_session.current_scene.choosing?
    assert_equal "Scene 1 of 7, Ilker's turn. Open the story in motion and decide the secret.\n#{sheet}", retry_call["prompt"], "the turn is not asked twice"
    assert_equal %w[system user assistant], @game_session.conversation.messages.pluck(:role)
  end

  test "the brief of an English game" do
    request = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert_includes request["system"], "Everything the players see is written in English"
    assert_equal <<~GAME, request["system"][/THIS GAME\n.*?\n(?=\n)/m]
      THIS GAME
      Quest: The caravan carrying Whitebend's winter salt has been missing for three days, and the blizzard will close the pass within the week. The route runs from Whitebend to Blizzard Pass: the tracks, the abandoned lodges, the rope bridge. What really happened: the caravan master, Orhan, sold the salt to the mountain clan and staged an ambush to hide it; the drivers who refused are held in the lodge cellar, and the clan's hunters still watch the pass. The village elder who sent the hero knows more than she says. Whitebend starves without the salt; the clan starves without the money.
      Tone: Balanced. Wonder and threat in equal measure; the world is strange, the stakes are plain.
      Length: 7 scenes; the last one is the finale.
      The character:
      - Ilker: Human (Versatile and balanced, at home in any class.), Warrior (Fights at the front, starts with a longsword and a round shield.), Soldier (Discipline, and the sight of war.). Health 31. Strength 16, Agility 11, Constitution 15, Intelligence 8, Wisdom 12, Charisma 14. Sets out with Longsword; Round shield.
    GAME
  end

  test "the brief of a Turkish game, read in the default locale like the narration job" do
    @game_session.update! locale: "tr"
    request = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert_includes request["system"], "Everything the players see is written in Turkish"
    assert_includes request["system"], "Quest: Akçabük köyünün kış tuzunu getiren kervan üç gündür kayıp", "the quest frame carries the Turkish place names"
    assert_includes request["system"], "Warrior (Fights at the front", "the brief stays in English whatever the page speaks"
    assert_includes request["system"], "Sets out with Uzun kılıç; Yuvarlak kalkan."
    assert_includes request["system"], "Geçidin ağzında rüzgâr bıçak gibi", "the voice sample speaks the game's language"
    assert_equal "Scene 1 of 7, Ilker's turn. Open the story in motion and decide the secret.\n#{sheet}", request["prompt"]
  end

  test "the surprise adventure takes its name from the first scene" do
    @game_session.update! quest: nil
    assert_equal "Surprise adventure", @game_session.title

    stub_understudy(*rewrites_of(SCENE_RESPONSE)) do
      error = assert_raises(Narrator::MalformedResponse) { narrate }
      assert_equal "the first scene must name the adventure", error.message
    end

    named = stub_understudy(SCENE_RESPONSE.sub('{"title"', '{"adventure": "Blizzard Salt", "title"')) { narrate }.sole

    assert_includes named["system"], "names the adventure"
    assert_equal "Blizzard Salt", @game_session.reload.title
    assert_equal "The Old Inn", @game_session.current_scene.title
  end

  test "a ready-made quest keeps its own name" do
    request = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert_not_includes request["system"], "names the adventure"
    assert_equal "The Lost Caravan", @game_session.reload.title
  end

  test "a downed character forces the defeat finale" do
    characters(:ilker_hero).update! hp: 0

    request = stub_understudy(FINALE_RESPONSE.sub('"outcome": "victory"', '"outcome": "defeat"')) { narrate }.sole

    assert_equal "Scene 1 of 7, Ilker's turn. Ilker has collapsed, their health spent. This scene is the finale and the story ends in defeat: pay off what was planted, then close.\n#{sheet(hp: 0)}", request["prompt"]
    assert @game_session.reload.finished?
    assert @game_session.outcome_defeat?
  end

  test "a downed character is denied another scene and a victory alike" do
    characters(:ilker_hero).update! hp: 0

    stub_understudy(*rewrites_of(SCENE_RESPONSE)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end
    stub_understudy(*rewrites_of(FINALE_RESPONSE)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert @game_session.scenes.sole.narrating?
    assert_not @game_session.reload.finished?
  end

  test "a roll is never resolved twice" do
    roll = play_first_scene

    resolve roll
    assert_empty stub_understudy(OUTCOME_RESPONSE) { roll.narrate }

    assert_equal 31 - 4, characters(:ilker_hero).reload.hp
    assert_equal 2, @game_session.conversation.ruby_llm_usages.count, "one scene and one outcome"
  end

  test "nothing is owed while the player is choosing" do
    requests = stub_understudy(SCENE_RESPONSE) do
      2.times { narrate }
    end

    assert_equal 1, requests.size
    assert_equal 1, @game_session.scenes.count
  end

  test "a half-written scene is finished on the next attempt" do
    stub_understudy(*rewrites_of("Prose arrived but no structure."), SCENE_RESPONSE) do
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

  test "an outcome without its prose is malformed" do
    roll = play_first_scene

    stub_understudy(*rewrites_of(OUTCOME_RESPONSE.sub("The drawer opens, but you cut your hand.", ""))) do
      assert_raises Narrator::MalformedResponse do
        roll.narrate
      end
    end

    assert_nil roll.reload.resolution
  end

  test "a finale closes the game" do
    play_and_continue die: 20

    stub_understudy(FINALE_RESPONSE) { narrate }

    finale = @game_session.current_scene
    assert finale.finale?
    assert finale.played?
    assert_empty finale.choices
    assert @game_session.reload.finished?
    assert @game_session.outcome_victory?
    assert @game_session.ended_at.present?
  end

  test "the finale ends as the dice decided" do
    play_and_continue

    stub_understudy(*rewrites_of(FINALE_RESPONSE)) do
      error = assert_raises(Narrator::MalformedResponse) { narrate }
      assert_equal "scene 2 is the finale and the story ends in defeat", error.message
    end
    assert_not @game_session.reload.finished?

    stub_understudy(FINALE_RESPONSE.sub('"outcome": "victory"', '"outcome": "defeat"')) { narrate }

    assert @game_session.reload.outcome_defeat?
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

    request = stub_understudy(FINALE_RESPONSE) { narrate }.sole

    assert_match(/This scene is the finale and the story ends in victory: pay off the secret and what was planted, then close.\nIlker: .*\n\z/, request["prompt"])
    assert @game_session.reload.finished?
  end

  test "a reply that breaks a rule is rewritten with the reason" do
    out_of_range = SCENE_RESPONSE.sub('"difficulty": 14', '"difficulty": 25')

    broken, rewrite = stub_understudy(out_of_range, SCENE_RESPONSE) { narrate }

    assert @game_session.scenes.sole.choosing?
    assert_equal "Scene 1 of 7, Ilker's turn. Open the story in motion and decide the secret.\n#{sheet}", broken["prompt"]
    assert_equal "Scene 1 of 7, Ilker's turn. Open the story in motion and decide the secret.\n#{sheet}\nYour last reply was rejected: difficulty 25 is outside 8-19. Write the whole reply again.", rewrite["prompt"],
      "the rejected reply is not in the conversation the rewrite sees"

    messages = @game_session.conversation.messages.reload
    assert_equal %w[system user assistant], messages.pluck(:role)
    assert_equal rewrite["prompt"], messages.second.content, "the reason stays in the transcript"
    assert_equal 2, @game_session.conversation.ruby_llm_usages.count, "both calls are still paid for"
  end

  test "a reply that keeps breaking the rules is given up after the rewrites, leaving no trace" do
    broken = SCENE_RESPONSE.sub('"difficulty": 14', '"difficulty": 25')

    stub_understudy(*rewrites_of(broken)) do
      error = assert_raises(Narrator::MalformedResponse) { narrate }
      assert_equal "difficulty 25 is outside 8-19", error.message
    end

    assert_equal 1 + Narrator::REWRITES, @game_session.conversation.ruby_llm_usages.count
    assert_equal %w[system], @game_session.conversation.messages.reload.pluck(:role)
    assert @game_session.scenes.sole.narrating?
  end

  test "a scene without its fence is malformed" do
    unfenced = SCENE_RESPONSE.delete("`").sub("json\n", "")

    stub_understudy(*rewrites_of(unfenced)) do
      error = assert_raises(Narrator::MalformedResponse) { narrate }
      assert_equal "the ```json block is missing", error.message
    end

    assert @game_session.scenes.sole.narrating?
  end

  test "a broken structure block is malformed" do
    stub_understudy(*rewrites_of("Prose arrived. ```json {broken``` ")) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert @game_session.scenes.sole.narrating?
  end

  test "the finale's closing words stream in before the game is closed" do
    play_and_continue die: 20

    streams = capture_turbo_stream_broadcasts(@game_session) do
      stub_understudy(FINALE_RESPONSE) { narrate }
    end

    assert_equal "The caravan bells echo down the valley as you ride into Whitebend.", streams.first.at("template").text
    assert_equal "refresh", streams.last["action"]
    assert @game_session.current_scene.finale?
    assert @game_session.reload.outcome_victory?
  end

  test "a scene is kept whole however long the narrator makes it" do
    @game_session.update! length: "long"
    long = SCENE_RESPONSE.sub('"title": "The Old Inn"', '"title": "The Old Coaching Inn by the Frozen Ford"').sub("Inside, a single candle is still burning.", "Snow falls. " * 300)

    stub_understudy(long) { narrate }

    scene = @game_session.scenes.sole
    assert_equal "The Old Coaching Inn by the Frozen Ford", scene.title
    assert_equal 300, scene.narration.scan("Snow falls.").size
  end

  test "the last scene must be the finale" do
    @game_session.current_scene.update! position: @game_session.scene_budget

    stub_understudy(*rewrites_of(SCENE_RESPONSE)) do
      error = assert_raises(Narrator::MalformedResponse) { narrate }
      assert_equal "scene 7 is the finale and the story ends in victory", error.message
    end

    assert_not @game_session.reload.finished?
  end

  test "an outcome is kept whole however long the narrator makes it" do
    roll = play_first_scene

    stub_understudy(OUTCOME_RESPONSE.sub("The drawer opens, but you cut your hand.", "The drawer sticks. " * 100)) { roll.narrate }

    assert_equal 100, roll.reload.resolution.scan("The drawer sticks.").size
  end

  test "the understudy narrates at no cost" do
    roll = play_first_scene
    resolve roll

    usages = @game_session.conversation.ruby_llm_usages
    assert_equal [ [ "understudy", "understudy" ] ], usages.pluck(:provider, :model).uniq
    assert_equal 2, usages.count
    assert_equal 0, @game_session.conversation.cost.total
  end

  private
    def sheet(hp: 31)
      "Ilker: #{hp}/31 health; carries Longsword, Healing potion (instant: +7 health, 1 use), Inn ledger (quest item); no statuses.\n"
    end

    def narrate
      Narrator.for(@game_session).narrate_scene(@game_session.current_scene)
    end

    def resolve(roll)
      stub_understudy(OUTCOME_RESPONSE) { roll.narrate }
    end

    def rewrites_of(reply)
      Array.new(1 + Narrator::REWRITES, reply)
    end

    def play_first_scene(die: 2)
      stub_understudy(SCENE_RESPONSE) { narrate }
      with_die(die) { choose_and_roll @game_session.current_scene }
    end

    def play_and_continue(die: 2)
      roll = play_first_scene(die: die)
      resolve roll
      roll.acknowledge
      roll
    end

    def choose_and_roll(scene)
      choice = scene.choices.first
      choice.choose
      scene.roll_dice(by: scene.active_player)
    end

    def build_roll
      scene = @game_session.scenes.create! position: @game_session.scene_budget + 10,
        active_player: players(:ilker_solo_host), state: :choosing, title: "Ara"
      choice = scene.choices.create! label: "Press on", stat: "strength", modifier: 3,
        target: 12
      choice.choose
      with_die(20) { scene.roll_dice(by: players(:ilker_solo_host)) }
    end
end
