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


      In scene 1 of 7, the story's first half, Ilker chose "#{roll.choice.label}": die 2, modifier #{format("%+d", roll.modifier)}, statuses +0, total #{roll.total} against #{roll.target}. #{roll.grade_label}, margin #{format("%+d", roll.margin)}. It does not work, and what goes wrong takes the story somewhere new instead of back for another try.
      Used since the scene began, already applied: Healing potion (+7 health).
      Ilker now: 31/31 health; carries Longsword, Inn ledger (quest item); no statuses.
      Tell only what this roll does, in a paragraph or two, and stop there: the next scene comes in my next message.
    CUE
  end

  test "a narrow success is told it costs something" do
    roll = play_first_scene(die: 11)

    request = stub_understudy(OUTCOME_RESPONSE) { roll.narrate }.sole

    assert_equal :narrow, roll.grade
    assert_includes request["prompt"], "margin +0. It works, but not for free: it costs Ilker something on the way.\n"
  end

  test "the roll before the last scene leaves the ending to it" do
    @game_session.current_scene.update! position: @game_session.scene_budget - 1
    roll = play_first_scene

    request = stub_understudy(OUTCOME_RESPONSE) { roll.narrate }.sole

    assert request["prompt"].end_with?("\nTell only what this roll does, in a paragraph or two, and stop there: the next scene comes in my next message.\n")
  end

  test "the last scene is played like any other, up to the moment that decides the story" do
    @game_session.current_scene.update! position: @game_session.scene_budget

    request = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert request["prompt"].start_with?("Scene 7 of 7, the story's last scene, Ilker's turn.")
    assert_includes request["prompt"], "the fork goes into the choices. Bring the story to the moment that decides it: the roll on the choice made here ends it.\n"
    assert @game_session.current_scene.choosing?
    assert_equal 3, @game_session.current_scene.choices.count
    assert_not @game_session.reload.finished?
  end

  test "the last roll tells the ending the dice decided" do
    roll = play_the_last_scene

    request = stub_understudy(ENDING_RESPONSE.sub("victory", "defeat")) { roll.narrate }.sole

    assert_includes request["prompt"], "\nIn scene 7 of 7, the story's last scene, Ilker chose "
    assert request["prompt"].end_with?(%(\nThis is the last roll, and the story ends with it, in defeat: 0 of the 0 rolls before it succeeded. Tell what this roll does, then how the story ends. The ending is only what the choices and rolls bring about: no one, Ilker included, makes a move in it that those did not set up. The block adds "outcome": "defeat".\n))
  end

  test "the scene and the roll in the middle of the story say so" do
    @game_session.current_scene.update! position: 4

    scene = stub_understudy(SCENE_RESPONSE) { narrate }.sole
    roll = with_die(2) { choose_and_roll @game_session.current_scene }
    outcome = stub_understudy(OUTCOME_RESPONSE) { roll.narrate }.sole

    assert scene["prompt"].start_with?("Scene 4 of 7, the middle of the story, Ilker's turn.")
    assert outcome["prompt"].include?("\nIn scene 4 of 7, the middle of the story, Ilker chose ")
  end

  test "a used item is settled by the outcome and not raised again by the next scene" do
    roll = play_first_scene
    items(:healing_potion).use
    resolve roll
    roll.acknowledge

    request = stub_understudy(SECOND_SCENE_RESPONSE) { narrate }.sole

    assert request["prompt"].include?("\n\nScene 2 of 7, the story's first half, Ilker's turn. Pick up where the last outcome stopped, without retelling it. The heroes do only what the players chose: where the way forks, the fork goes into the choices.\nIlker, human warrior (background: soldier): ")
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

  test "choices may share a stat, number two, and have their difficulty kept in range" do
    two = SCENE_RESPONSE.sub('"stat": "intelligence"', '"stat": "strength"').sub('"difficulty": 14', '"difficulty": 25')
      .sub(%(,\n   {"label": "Listen at the stable in silence", "stat": "wisdom", "difficulty": 12}), "")

    stub_understudy(two) { narrate }

    assert_equal [ [ "strength", 10 ], [ "strength", 19 ] ], @game_session.current_scene.choices.order(:id).pluck(:stat, :target)
  end

  test "a first scene without a title still opens the game" do
    stub_understudy(SCENE_RESPONSE.sub('"title": "The Old Inn", ', "")) { narrate }

    scene = @game_session.scenes.sole
    assert_nil scene.title
    assert_not scene.opening?
    assert scene.choosing?
  end

  test "a choice on a stat the hero does not have is malformed" do
    unknown = SCENE_RESPONSE.sub('"stat": "intelligence"', '"stat": "luck"')

    stub_understudy(*rewrites_of(unknown)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert @game_session.scenes.sole.narrating?
  end

  test "a scene without choices is malformed" do
    stub_understudy(*rewrites_of(ENDING_RESPONSE)) do
      error = assert_raises(Narrator::MalformedResponse) { narrate }
      assert_equal "the scene has no choices", error.message
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

    assert_includes first["system"], "The story runs 7 scenes."
    assert_includes first["system"], "- The place: A fog-bound fishing village"
    assert_includes first["system"], "Warrior"
    assert_equal "Scene 1 of 7, the story's first half, Ilker's turn.\n#{sheet}", first["prompt"], "the first turn has no story before it"

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
    assert request["prompt"].include?("\n\nScene 5 of 7, the story's second half, Ilker's turn. Pick up where the last outcome stopped, without retelling it. The heroes do only what the players chose: where the way forks, the fork goes into the choices.\nIlker, human warrior (background: soldier): ")
  end

  test "a turn the provider never answered is answered on the next attempt" do
    stub_understudy(nil) do
      assert_raises(RubyLLM::ServerError) { narrate }
    end

    retry_call = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert @game_session.current_scene.choosing?
    assert_equal "Scene 1 of 7, the story's first half, Ilker's turn.\n#{sheet}", retry_call["prompt"], "the turn is not asked twice"
    assert_equal %w[system user assistant], @game_session.conversation.messages.pluck(:role)
  end

  test "the brief of an English game" do
    request = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert_includes request["system"], "Tell the story in English"
    assert_equal <<~GAME, request["system"][/^The quest, .*?\n(?=\n)/m]
      The quest, drawn from a fate card; the names and the details are yours to give:
      - The place: A fog-bound fishing village
      - The trouble: A child went out at dusk and has not come back
      - At the heart of it: An old weather-reader who pleases no one
      What really happened, which only you know, takes this shape: the one asking for help is the cause. Settle who did what and why before the first scene.
      The tone: balanced. Wonder and danger in equal measure.
      The story runs 7 scenes.
      The hero:
      - Ilker: Human, Warrior (Fights at the front, starts with a longsword and a round shield.). Background: Soldier. Health 31. Strength 16, Agility 11, Constitution 15, Intelligence 8, Wisdom 12, Charisma 14. Sets out with Longsword; Round shield.
    GAME
  end

  test "a Turkish game is briefed in Turkish, even from the narration job's default locale" do
    @game_session.update! locale: "tr"
    request = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert_includes request["system"], "sade, doğal, gündelik Türkçeyle"
    assert_includes request["system"], "- Yer: Sisli bir balıkçı köyü\n- Dert: Bir çocuk akşamüstü dışarı çıktı ve dönmedi\n"
    assert_includes request["system"], "Aslında olan, yalnızca senin bildiğin, şu biçimde: yardım isteyen, derdin sebebi."
    assert_includes request["system"], "- Ilker: İnsan, Savaşçı (Ön safta dövüşür;"
    assert_includes request["system"], "Geçmişi: Asker. Can 31. Güç 16, Çeviklik 11,"
    assert_includes request["system"], "Yola çıkarken yanında: Uzun kılıç; Yuvarlak kalkan."
    assert_no_match(/Warrior|Strength|The quest/, request["system"])
    assert_equal "Scene 1 of 7, the story's first half, Ilker's turn.\n#{sheet}", request["prompt"]
  end

  test "the adventure takes its name from the first scene" do
    @game_session.update! surprise: true
    assert_equal "Surprise adventure", @game_session.title

    named = stub_understudy(SCENE_RESPONSE.sub('{"title"', '{"adventure": "Blizzard Salt", "title"')) { narrate }.sole

    assert_includes named["system"], "names the adventure"
    assert_equal "Blizzard Salt", @game_session.reload.title
    assert_equal "The Old Inn", @game_session.current_scene.title
  end

  test "a roll that takes the hero's last health ends the story in defeat" do
    characters(:ilker_hero).update! hp: 3
    roll = play_first_scene

    told, rewritten = stub_understudy(OUTCOME_RESPONSE, OUTCOME_RESPONSE.sub('{"hp": -4}', '{"hp": -4, "outcome": "defeat"}')) { roll.narrate }

    assert_includes told["prompt"], %(\nThis roll can take the last of Ilker's health. If it does, Ilker falls and the story ends here in defeat: tell how, and add "outcome": "defeat" to the block. If not, tell only what this roll does)
    assert_includes rewritten["prompt"], %(Your last reply was rejected: the story ends with this roll, in defeat: tell the ending and add "outcome": "defeat" to the block.)
    assert_equal 0, characters(:ilker_hero).reload.hp
    assert @game_session.current_scene.finale?
    assert @game_session.reload.finished?
    assert @game_session.outcome_defeat?
  end

  test "a party's scene puts the rest of the party beside the hero, but not those who left" do
    players(:deniz_solo_host).update! game_session: @game_session
    @game_session.players.create!(user: users(:sevval)).create_character! characters(:deniz_hero).attributes.slice("race", "klass", "background", "stats")
    users(:sevval).destroy!

    request = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert request["prompt"].end_with?("\nIn the scene with Ilker: Deniz, human healer (background: soldier), 28/28 health.\n")
  end

  test "a party's ending leaves every hero to what the dice set up, each with a part in it" do
    players(:deniz_solo_host).update! game_session: @game_session
    roll = play_the_last_scene

    request = stub_understudy(ENDING_RESPONSE.sub("victory", "defeat")) { roll.narrate }.sole

    assert_includes request["prompt"], %(no one, Ilker and Deniz included, makes a move in it that those did not set up. Each of them has a part in it: Ilker tried "Read the dusty ledger" (failed); Deniz tried nothing. The block adds)
  end

  test "a roll that leaves the hero standing before the last scene does not end the story" do
    roll = play_first_scene

    stub_understudy(*rewrites_of(OUTCOME_RESPONSE.sub('{"hp": -4}', '{"hp": -4, "outcome": "defeat"}'))) do
      error = assert_raises(Narrator::MalformedResponse) { roll.narrate }
      assert_equal "the story goes on after this roll, so the block has no outcome", error.message
    end

    assert_nil roll.reload.resolution
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

  test "the last roll closes the game on its ending" do
    roll = play_the_last_scene die: 20

    stub_understudy(ENDING_RESPONSE) { roll.narrate }

    finale = @game_session.current_scene
    assert finale.finale?
    assert_equal 3, finale.choices.count
    assert_equal "The drawer gives, and the caravan bells echo down the valley as you ride into Whitebend.", finale.closing
    assert @game_session.reload.finished?
    assert @game_session.outcome_victory?
  end

  test "a scene that hands the hero something puts it on the sheet, but only a roll costs health" do
    giving = SCENE_RESPONSE.sub('"location": "Whitebend",', <<~JSON.chomp)
      "location": "Whitebend", "hp": -5,
       "carries": {"Longsword": "kept", "Healing potion": "kept", "Inn ledger": "with the innkeeper", "Village purse": {"kind": "quest", "description": "The harvest money"}},
       "statuses_gained": [{"name": "Watched", "modifier": -1, "turns": 2}, {"name": "Blessed", "modifier": 2, "turns": 2}],
    JSON

    stub_understudy(giving) { narrate }

    character = characters(:ilker_hero).reload
    assert character.items.quest.exists?(name: "Village purse")
    assert_not character.items.exists?(name: "Inn ledger")
    assert_equal [ "Watched" ], character.status_effects.pluck(:name), "only a critical roll grants a boon"
    assert_equal 31, character.hp
    assert_equal [ "Village purse" ], @game_session.current_scene.items_gained.pluck("name")
  end

  test "the ending settles what the hero leaves behind" do
    roll = play_the_last_scene die: 20

    stub_understudy(ENDING_RESPONSE.sub('{"outcome"', '{"carries": {"Longsword": "left in the snow", "Healing potion": "kept", "Inn ledger": "kept"}, "outcome"')) { roll.narrate }

    assert_not characters(:ilker_hero).items.exists?(name: "Longsword")
    assert @game_session.reload.finished?
  end

  test "the ending is the one the dice decided" do
    roll = play_the_last_scene

    stub_understudy(*rewrites_of(ENDING_RESPONSE)) do
      error = assert_raises(Narrator::MalformedResponse) { roll.narrate }
      assert_equal %(the story ends with this roll, in defeat: tell the ending and add "outcome": "defeat" to the block), error.message
    end
    assert_not @game_session.reload.finished?

    stub_understudy(ENDING_RESPONSE.sub("victory", "defeat")) { roll.narrate }

    assert @game_session.reload.outcome_defeat?
  end

  test "a reply that breaks a rule is rewritten with the reason" do
    unfenced = SCENE_RESPONSE.delete("`")

    broken, rewrite = stub_understudy(unfenced, SCENE_RESPONSE) { narrate }

    assert @game_session.scenes.sole.choosing?
    assert_equal "Scene 1 of 7, the story's first half, Ilker's turn.\n#{sheet}", broken["prompt"]
    assert_equal "Scene 1 of 7, the story's first half, Ilker's turn.\n#{sheet}\nYour last reply was rejected: the ```json block is missing. Write the whole reply again.", rewrite["prompt"],
      "the rejected reply is not in the conversation the rewrite sees"

    messages = @game_session.conversation.messages.reload
    assert_equal %w[system user assistant], messages.pluck(:role)
    assert_equal rewrite["prompt"], messages.second.content, "the reason stays in the transcript"
    assert_equal 2, @game_session.conversation.ruby_llm_usages.count, "both calls are still paid for"
  end

  test "a reply that keeps breaking the rules is given up after the rewrites, leaving no trace" do
    stub_understudy(*rewrites_of(ENDING_RESPONSE)) do
      error = assert_raises(Narrator::MalformedResponse) { narrate }
      assert_equal "the scene has no choices", error.message
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

  test "a scene is kept whole however long the narrator makes it" do
    @game_session.update! length: "long"
    long = SCENE_RESPONSE.sub('"title": "The Old Inn"', '"title": "The Old Coaching Inn by the Frozen Ford"').sub("Inside, a single candle is still burning.", "Snow falls. " * 300)

    stub_understudy(long) { narrate }

    scene = @game_session.scenes.sole
    assert_equal "The Old Coaching Inn by the Frozen Ford", scene.title
    assert_equal 300, scene.narration.scan("Snow falls.").size
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
      "Ilker, human warrior (background: soldier): #{hp}/31 health; carries Longsword, Healing potion (instant: +7 health, 1 use), Inn ledger (quest item); no statuses.\n"
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

    def play_the_last_scene(die: 2)
      @game_session.current_scene.update! position: @game_session.scene_budget
      play_first_scene die: die
    end

    def choose_and_roll(scene)
      choice = scene.choices.first
      choice.choose
      scene.roll_dice(by: scene.active_player)
    end
end
