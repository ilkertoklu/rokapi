require "test_helper"
require "turbo/broadcastable/test_helper"

class NarratorTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  CLUES_PLAN = <<~PLAN
    Hidden: Mara hid her son in the lighthouse to keep him from the press gang.

    Clues:
    1. Mara's shawl hangs on the lighthouse door.
    2. The boy's boots stand dry under the stairs.
    3. The press gang's list carries the boy's name.
  PLAN

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


      In scene 1 of 7, the story's first half, Ilker chose "#{roll.choice.label}": die 2, modifier #{format("%+d", roll.modifier)}, statuses +0, total #{roll.total} against #{roll.target}. #{roll.grade_label}, margin #{format("%+d", roll.margin)}. It does not work, and Ilker pays with something that stays lost unless a later roll wins it back: one of the things the plan puts at stake, someone's trust or a way now closed. A hurt alone is not the price, no one steps in to help and nothing turns up by luck. Ilker learns nothing of what the plan hides from it: no clue is handed over. The story moves on from there, not back for a second try. Add "mark" to the block: one short sentence in English naming what this roll changed for good. Keep true what the story has shown: who holds what and who knows what, where everyone is and how much time is left.
      Used since the scene began, already applied: Healing potion (+7 health).
      Ilker now: 31/31 health; carries Longsword, Inn ledger (quest item); no statuses.
      Tell only what this roll does, in a paragraph or two, and stop there: the next scene comes in my next message.
    CUE
  end

  test "a narrow success is told it costs something" do
    roll = play_first_scene(die: 11)

    request = stub_understudy(OUTCOME_RESPONSE) { roll.narrate }.sole

    assert_equal :narrow, roll.grade
    assert_includes request["prompt"], %(margin +0. It works, but not for free: it costs Ilker something on the way. What it wins stays won to the end. Add "mark")
  end

  test "a success before the last wins the plan's next clue in order" do
    @game_session.update! plan: CLUES_PLAN
    roll = play_first_scene(die: 15)

    request = stub_understudy(OUTCOME_RESPONSE) { roll.narrate }.sole

    assert_equal :solid, roll.grade
    assert_includes request["prompt"], %(margin +4. It works. What it wins stays won to the end. It also hands Ilker clue 1 of the plan (none found so far): show it plainly, as this attempt comes by it. Add "mark" to the block: one short sentence in English naming what this roll changed for good. Keep true what the story has shown: who holds what and who knows what, where everyone is and how much time is left.\n)
  end

  test "a failure before the last hands over no clue and costs something lasting" do
    @game_session.update! plan: CLUES_PLAN
    roll = play_first_scene

    request = stub_understudy(OUTCOME_RESPONSE) { roll.narrate }.sole

    assert_not roll.success?
    assert_includes request["prompt"], "margin -9. It does not work, and Ilker pays with something that stays lost unless a later roll wins it back"
    assert_includes request["prompt"], %(no clue is handed over. The story moves on from there, not back for a second try. Add "mark")
    assert_not_includes request["prompt"], "It also hands Ilker clue"
    assert_not_includes request["prompt"].split("</conversation_so_far>").last, %("clue":)
  end

  test "a success on a choice that leads to no clue wins only what it reached for" do
    @game_session.update! plan: CLUES_PLAN
    stub_understudy(SCENE_RESPONSE) { narrate }
    aside = @game_session.current_scene.choices.find_by!(label: "Force the drawer open")
    aside.choose
    roll = with_die(15) { @game_session.current_scene.roll_dice(by: @game_session.host) }

    request = stub_understudy(OUTCOME_RESPONSE) { roll.narrate }.sole

    assert roll.success?
    assert_includes request["prompt"], %(It works. What it wins stays won to the end. It wins no clue: what the plan hides stays hidden. Add "mark")
    assert_empty @game_session.reload.clues_found
  end

  test "a success wins no clue from a plan that numbers none" do
    roll = play_first_scene(die: 15)

    request = stub_understudy(OUTCOME_RESPONSE) { roll.narrate }.sole

    assert_includes request["prompt"], %(margin +4. It works. What it wins stays won to the end. Add "mark")
    assert_not_includes request["prompt"], "It also hands Ilker clue"
  end

  test "the clues found so far are named in every later scene and roll" do
    @game_session.update! plan: CLUES_PLAN
    roll = play_first_scene(die: 15)
    resolve roll
    roll.acknowledge

    scene = stub_understudy(SECOND_SCENE_RESPONSE) { narrate }.sole
    later = with_die(15) { choose_and_roll @game_session.current_scene }
    outcome = stub_understudy(OUTCOME_RESPONSE) { later.narrate }.sole

    assert_equal [ 1 ], @game_session.clues_found
    assert_includes scene["prompt"], "\n\nScene 2 of 7, the story's first half, Ilker's turn. Pick up where the last outcome stopped, without retelling it, and keep true what the story has shown: who holds what and who knows what, where everyone is and how much time is left. Clues found so far: 1. The heroes do only what the players chose: where the way forks, the fork goes into the choices, and what a way not taken would have won does not turn up by itself. At least one choice is a way to come by clue 2, one of the two the plan gives or one as likely from where Ilker stands, and adds \"clue\": true to its entry in the block; a success on it wins the clue, and a success on any other choice wins only what it reaches for.\n"
    assert_includes outcome["prompt"], %(It also hands Ilker clue 2 of the plan (found so far: 1): show it plainly, as this attempt comes by it.)
  end

  test "what a roll changed for good is kept and named in every later scene and roll" do
    roll = play_first_scene(die: 15)
    stub_understudy(OUTCOME_RESPONSE.sub('{"hp": -4}', '{"mark": "The innkeeper trusts Ilker with the ledger."}')) { roll.narrate }
    roll.acknowledge

    scene = stub_understudy(SECOND_SCENE_RESPONSE) { narrate }.sole
    later = choose_and_roll @game_session.current_scene
    outcome = stub_understudy(OUTCOME_RESPONSE) { later.narrate }.sole

    assert_equal [ "The innkeeper trusts Ilker with the ledger." ], @game_session.marks
    assert_includes scene["prompt"], "No clue found yet. What the rolls have changed so far, and it stays so: The innkeeper trusts Ilker with the ledger. The heroes do only"
    assert_includes outcome["prompt"], "how much time is left.\nWhat the rolls have changed so far, and it stays so: The innkeeper trusts Ilker with the ledger.\nIlker now: "
  end

  test "a clue the rolls are too late to win is shown by the trouble itself and counts as found" do
    @game_session.update! plan: CLUES_PLAN
    @game_session.current_scene.update! position: 4

    scene = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert_includes scene["prompt"], "No clue found yet. The story cannot wait for clue 1 any longer: the trouble moves on in this scene: someone in it acts on what they want or fear and takes something the plan puts at stake, and what they do shows that clue plainly, with no mishap or chance behind it. The heroes do only"
    assert_includes scene["prompt"], "At least one choice is a way to come by clue 2,"
    assert_equal 1, @game_session.current_scene.effects["clue"]
    assert_equal [ 1 ], @game_session.reload.clues_found

    roll = with_die(15) { choose_and_roll @game_session.current_scene }
    outcome = stub_understudy(OUTCOME_RESPONSE) { roll.narrate }.sole

    assert_includes outcome["prompt"], "It also hands Ilker clue 2 of the plan (found so far: 1)"
    assert_equal [ 1, 2 ], @game_session.reload.clues_found
  end

  test "a scene with rolls enough left to win the clues waits for them" do
    @game_session.update! plan: CLUES_PLAN
    @game_session.current_scene.update! position: 3

    scene = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert_not_includes scene["prompt"], "The story cannot wait"
    assert_not @game_session.current_scene.effects.key?("clue")
    assert_empty @game_session.reload.clues_found
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
    assert_includes request["prompt"], "the fork goes into the choices, and what a way not taken would have won does not turn up by itself. Bring the story to the moment that decides it: the roll on the choice made here ends it.\n"
    assert @game_session.current_scene.choosing?
    assert_equal 3, @game_session.current_scene.choices.count
    assert_not @game_session.reload.finished?
  end

  test "the last roll weighs every roll before it, leaves the ending to the story and hands over no clue" do
    roll = play_the_last_scene

    request = stub_understudy(ENDING_RESPONSE.sub("victory", "defeat")) { roll.narrate }.sole

    assert_includes request["prompt"], "\nIn scene 7 of 7, the story's last scene, Ilker chose "
    assert_no_match(/"clue"|"mark"|no clue is handed over/, request["prompt"].split("</conversation_so_far>").last)
    assert request["prompt"].end_with?(%(\nThis is the last roll, and the story ends with it. So far Ilker tried "Read the dusty ledger" (failed). Victory or defeat is the story's to decide: weigh what the heroes found and did, this roll as one among the rest, against the plan's endings, and give the ending they have earned. Tell what this roll does, then how the story ends, with only what the story has shown: the ending rests on why it all happened, as the clues showed it; what the heroes never found stays unsaid, and no one explains it. A roll that succeeds here gets the heroes what they reached for; one that fails costs them something, but does not undo what the rolls before it won. The heroes settle the question with what they did, and make no move the players did not choose; the others go on as they want and fear, and no one steps in to win or lose it for them. Tell it as scenes the hero sees and hears, to the last line: the reckoning happens on the page, not in a summary, and no one says what the story meant. The block adds "outcome": "victory" or "defeat".\n))
  end

  test "the ending shows what the rolls changed" do
    @game_session.update! plan: CLUES_PLAN
    earlier = play_first_scene(die: 15)
    stub_understudy(OUTCOME_RESPONSE.sub('{"hp": -4}', '{"mark": "The innkeeper trusts Ilker with the ledger."}')) { earlier.narrate }
    earlier.acknowledge
    @game_session.current_scene.update! position: @game_session.scene_budget
    stub_understudy(SECOND_SCENE_RESPONSE) { narrate }
    roll = with_die(15) { choose_and_roll @game_session.current_scene }

    request = stub_understudy(ENDING_RESPONSE) { roll.narrate }.sole
    cue = request["prompt"].split("</conversation_so_far>").last

    assert roll.success?
    assert_includes cue, "SUCCESS, margin +4. Keep true what the story has shown: who holds what and who knows what, where everyone is and how much time is left.\nWhat the rolls have changed so far, and it stays so: The innkeeper trusts Ilker with the ledger.\n"
    assert_includes cue, "but does not undo what the rolls before it won. Everything the rolls changed shows in the ending: what was won is there to be used and people act on it, what was lost and never won back is missing. The heroes settle the question"
    assert_no_match(/"clue"|"mark"/, cue)
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

    assert request["prompt"].include?("\n\nScene 2 of 7, the story's first half, Ilker's turn. Pick up where the last outcome stopped, without retelling it, and keep true what the story has shown: who holds what and who knows what, where everyone is and how much time is left. No clue found yet. The heroes do only what the players chose: where the way forks, the fork goes into the choices, and what a way not taken would have won does not turn up by itself.\nIlker, human warrior (background: soldier): ")
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

  test "a choice's difficulty word sets the target to roll against" do
    worded = SCENE_RESPONSE.sub('"difficulty": 10', '"difficulty": "easy"').sub('"difficulty": 14', '"difficulty": "hard"').sub('"difficulty": 12', '"difficulty": "medium"')

    stub_understudy(worded) { narrate }

    assert_equal [ 7, 13, 10 ], @game_session.current_scene.choices.order(:id).pluck(:target)
    assert_equal %w[easy hard medium], @game_session.current_scene.choices.order(:id).map(&:difficulty)
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
    assert_includes first["system"], "Mara hid her son in the lighthouse"
    assert_includes first["system"], "Warrior"
    assert_equal opening, first["prompt"], "the first turn has no story before it"

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

  test "a game is planned once, before its first scene, and the brief carries the plan" do
    @game_session.update! plan: nil

    planner, critic, scene = stub_understudy(*PLANNING, SCENE_RESPONSE) { narrate }

    assert_equal PLAN_RESPONSE.strip, @game_session.reload.plan
    assert_includes planner["system"], "You plan a story for Rokapi"
    assert_equal PLAN_RESPONSE.strip, critic["prompt"]
    assert_includes scene["system"], "that the players have not already seen.\n\n#{PLAN_RESPONSE.strip}\n\nThe tone:"
    assert @game_session.current_scene.choosing?

    roll = with_die(2) { choose_and_roll @game_session.current_scene }
    assert_equal 1, stub_understudy(OUTCOME_RESPONSE) { roll.narrate }.size, "the plan is written only once"
  end

  test "a planned game keeps one conversation for the story beside the planner's and the critic's" do
    @game_session.update! plan: nil

    planner, critic, scene = stub_understudy(*PLANNING, SCENE_RESPONSE) { narrate }
    roll = with_die(2) { choose_and_roll @game_session.current_scene }
    stub_understudy(OUTCOME_RESPONSE) { roll.narrate }

    assert_equal %w[narration planning planning], @game_session.conversations.pluck(:purpose).sort
    assert_equal [ planner["system"], critic["system"] ], @game_session.conversations.planning.order(:id).map { it.messages.first.content }
    assert_equal scene["system"], @game_session.conversation.messages.first.content
    assert_equal 2, @game_session.conversation.ruby_llm_usages.count, "one scene and one outcome"
  end

  test "a planned game's cost includes the planner and the critic" do
    @game_session.update! plan: nil
    stub_understudy(*PLANNING, SCENE_RESPONSE) { narrate }

    RubyLLM::ActiveRecord::Usage.update_all total_cost: 0.25
    @game_session.reload

    assert_equal 0.25, @game_session.conversation.cost.total
    assert_equal 0.75, @game_session.cost.total
  end

  test "a planner that never answers leaves the game unplanned and the scene unwritten" do
    @game_session.update! plan: nil

    stub_understudy(nil) do
      assert_raises(RubyLLM::ServerError) { narrate }
    end

    assert_nil @game_session.reload.plan
    assert_nil @game_session.conversation
    assert @game_session.current_scene.narrating?
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
    assert request["prompt"].include?("\n\nScene 5 of 7, the story's second half, Ilker's turn. Pick up where the last outcome stopped, without retelling it, and keep true what the story has shown: who holds what and who knows what, where everyone is and how much time is left. No clue found yet. The heroes do only what the players chose: where the way forks, the fork goes into the choices, and what a way not taken would have won does not turn up by itself.\nIlker, human warrior (background: soldier): ")
  end

  test "a turn the provider never answered is answered on the next attempt" do
    stub_understudy(nil) do
      assert_raises(RubyLLM::ServerError) { narrate }
    end

    retry_call = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert @game_session.current_scene.choosing?
    assert_equal opening, retry_call["prompt"], "the turn is not asked twice"
    assert_equal %w[system user assistant], @game_session.conversation.messages.pluck(:role)
  end

  test "the brief of an English game" do
    request = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert_includes request["system"], "Tell the story in English"
    assert_equal <<~GAME, request["system"][/^The story's plan .*?\n(?=\nBe the game master)/m]
      The story's plan is below, and only you know it. Add the detail it leaves out, but never go against it. The players know only what the story has shown them, and their heroes know no more: bring in every person, place and past event plainly, saying who or what it is, before anyone leans on it. As the story opens, everyone believes what the plan says is believed; tell it that way. What the plan hides comes out only through its clues, and a clue is won, in the plan's order, by a successful roll on a choice that leads to it: I tell you when. A clue is shown plainly enough that the players can tell what it points to, as the hero finds it and in your own words: the plan's notes are for you, and a clue not yet found is not hinted at. In the second half the clues turn the story, and by the end the players know the whole of it. A roll truly changes something: what a success wins stays won to the end, what a failure loses stays lost unless a later roll wins it back, and the ending is built on them. Invent only the detail that colours a scene, never a new secret, danger, object or power the plan does not hold, and nothing the ending turns on that the players have not already seen.

      Mara hid her son in the lighthouse to keep him from the press gang, then begged the village to search for him.

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
    assert_includes request["system"], "Hikâyenin planı aşağıda ve onu yalnızca sen biliyorsun. Eksik bıraktığı ayrıntıları sen ekle, ama ona hiçbir yerde ters düşme. "
    assert_includes request["system"], "sonun dayandığı her şeyi de oyuncular önceden görmüş olsun.\n\nMara hid her son"
    assert_includes request["system"], "- Ilker: İnsan, Savaşçı (Ön safta dövüşür;"
    assert_includes request["system"], "Geçmişi: Asker. Can 31. Güç 16, Çeviklik 11,"
    assert_includes request["system"], "Yola çıkarken yanında: Uzun kılıç; Yuvarlak kalkan."
    assert_no_match(/Warrior|Strength|The story's plan/, request["system"])
    assert_equal opening, request["prompt"]
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

  test "a roll that takes a party hero's last health leaves the hero fallen and the story going on" do
    players(:deniz_solo_host).update! game_session: @game_session
    characters(:ilker_hero).update! hp: 3
    roll = play_first_scene

    told, rewritten = stub_understudy(OUTCOME_RESPONSE.sub('{"hp": -4}', '{"hp": -4, "outcome": "defeat"}'), OUTCOME_RESPONSE) { roll.narrate }

    assert_includes told["prompt"], %(\nThis roll can take the last of Ilker's health. If it does, Ilker falls and takes no more turns, and the story goes on with the others: tell how, and leave "outcome" out of the block. Either way, tell only what this roll does, in a paragraph or two, and stop there: the next scene comes in my next message.\n)
    assert_includes rewritten["prompt"], "Your last reply was rejected: the story goes on after this roll, so the block has no outcome."
    assert_equal 0, characters(:ilker_hero).reload.hp
    assert_not @game_session.reload.finished?
    assert_not @game_session.current_scene.finale?

    roll.acknowledge
    next_scene = @game_session.current_scene
    assert_equal players(:deniz_solo_host), next_scene.active_player
    assert_empty next_scene.companions, "the fallen hero is no longer in the scene"
  end

  test "the solo brief ends the story on the hero's last health, a party's brief lets a hero fall and the story go on" do
    solo = { "en" => %(\nThe roll that ends the story, the last scene's or one that takes a hero's last health, tells what it does and then the ending the story has earned; its block adds "outcome": "victory" or "defeat".\n\nEvery block),
             "tr" => %(\nHikâyeyi bitiren zarın sonucu, son sahnenin zarı da olsa bir kahramanın son canını alan zar da olsa, önce zarın getirdiğini, sonra hikâyenin hak ettiği sonu anlatır; bloğuna "outcome": "victory" ya da "defeat" eklenir.\n\nHer blok) }
    party = { "en" => %(A hero who loses their last health before then falls and takes no more turns, and the story goes on with the others; that roll's block has no outcome.\n\nEvery block),
              "tr" => %(Ondan önce son canını yitiren kahraman düşer ve bir daha sıra almaz, hikâye öbürleriyle sürer; o zarın bloğunda outcome olmaz.\n\nHer blok) }

    solo.each { |locale, line| assert_includes RubyLLM.render_prompt("narrator/instructions.#{locale}", game: @game_session), line }

    players(:deniz_solo_host).update! game_session: @game_session
    party.each do |locale, line|
      brief = RubyLLM.render_prompt("narrator/instructions.#{locale}", game: @game_session)
      assert_includes brief, line
      assert_not_includes brief, solo.fetch(locale)
    end
  end

  test "the last hero standing who falls ends the party's story in defeat" do
    players(:deniz_solo_host).update! game_session: @game_session
    characters(:deniz_hero).update! hp: 0
    characters(:ilker_hero).update! hp: 3
    roll = play_first_scene

    told = stub_understudy(OUTCOME_RESPONSE.sub('{"hp": -4}', '{"hp": -4, "outcome": "defeat"}')) { roll.narrate }.sole

    assert_includes told["prompt"], %(\nThis roll can take the last of Ilker's health. If it does, Ilker falls and the story ends here in defeat: tell how)
    assert @game_session.reload.outcome_defeat?
  end

  test "a party's last roll decides the story even when it takes the roller's last health" do
    players(:deniz_solo_host).update! game_session: @game_session
    characters(:ilker_hero).update! hp: 3
    roll = play_the_last_scene

    stub_understudy(ENDING_RESPONSE.sub("{", '{"hp": -4, ')) { roll.narrate }

    assert_equal 0, characters(:ilker_hero).reload.hp
    assert @game_session.reload.outcome_victory?
  end

  test "a party's ending weighs what a fallen hero tried" do
    players(:deniz_solo_host).update! game_session: @game_session
    play_and_continue
    characters(:ilker_hero).update! hp: 0
    @game_session.current_scene.update! position: @game_session.scene_budget
    stub_understudy(SCENE_RESPONSE) { narrate }
    roll = with_die(2) { choose_and_roll @game_session.current_scene }

    request = stub_understudy(ENDING_RESPONSE) { roll.narrate }.sole

    assert_includes request["prompt"], %(So far Ilker tried "Read the dusty ledger" (failed); Deniz tried "Read the dusty ledger" (failed). Victory or defeat)
    assert_not_includes request["prompt"], "In the scene with Deniz"
  end

  test "a party's scene puts the rest of the party beside the hero, but not those who left" do
    players(:deniz_solo_host).update! game_session: @game_session
    @game_session.players.create!(user: users(:sevval)).create_character! characters(:deniz_hero).attributes.slice("race", "klass", "background", "stats")
    users(:sevval).destroy!

    request = stub_understudy(SCENE_RESPONSE) { narrate }.sole

    assert request["prompt"].end_with?("\nIn the scene with Ilker: Deniz, human healer (background: soldier), 28/28 health.\n")
  end

  test "a party's ending weighs what each hero tried, and each has a part in it" do
    players(:deniz_solo_host).update! game_session: @game_session
    roll = play_the_last_scene

    request = stub_understudy(ENDING_RESPONSE.sub("victory", "defeat")) { roll.narrate }.sole

    assert_includes request["prompt"], %(So far Ilker tried "Read the dusty ledger" (failed); Deniz tried nothing. Victory or defeat)
    assert_includes request["prompt"], %(The heroes settle the question with what they did, each with a part in it, and make no move the players did not choose;)
    assert_includes request["prompt"], "Tell it as scenes the heroes see and hear, to the last line"
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

  test "the ending is the one the story earned, whatever the last die" do
    roll = play_the_last_scene

    stub_understudy(ENDING_RESPONSE) { roll.narrate }

    assert_not roll.success?
    assert @game_session.reload.outcome_victory?
  end

  test "a last roll that leaves the ending untold is rewritten with the reason" do
    roll = play_the_last_scene

    told, rewritten = stub_understudy(OUTCOME_RESPONSE, ENDING_RESPONSE.sub("victory", "defeat")) { roll.narrate }

    assert_not_includes told["prompt"], "Your last reply was rejected"
    assert_includes rewritten["prompt"], %(Your last reply was rejected: the story ends with this roll: tell the ending the story has earned and add "outcome": "victory" or "defeat" to the block.)
    assert @game_session.reload.outcome_defeat?
  end

  test "a last roll that ends in neither victory nor defeat is given up after the rewrites" do
    roll = play_the_last_scene

    stub_understudy(*rewrites_of(ENDING_RESPONSE.sub("victory", "stalemate"))) do
      error = assert_raises(Narrator::MalformedResponse) { roll.narrate }
      assert_equal %(the story ends with this roll: tell the ending the story has earned and add "outcome": "victory" or "defeat" to the block), error.message
    end

    assert_nil roll.reload.resolution
    assert_not @game_session.reload.finished?
  end

  test "a last roll that takes the hero's last health ends in defeat, whatever the story says" do
    characters(:ilker_hero).update! hp: 3
    roll = play_the_last_scene

    told, rewritten = stub_understudy(ENDING_RESPONSE.sub("{", '{"hp": -4, '), ENDING_RESPONSE.sub("{", '{"hp": -4, ').sub("victory", "defeat")) { roll.narrate }

    assert_includes told["prompt"], "This is the last roll"
    assert_includes rewritten["prompt"], %(Your last reply was rejected: the story ends with this roll, in defeat: tell the ending and add "outcome": "defeat" to the block.)
    assert_equal 0, characters(:ilker_hero).reload.hp
    assert @game_session.reload.outcome_defeat?
  end

  test "a reply that breaks a rule is rewritten with the reason" do
    unfenced = SCENE_RESPONSE.delete("`")

    broken, rewrite = stub_understudy(unfenced, SCENE_RESPONSE) { narrate }

    assert @game_session.scenes.sole.choosing?
    assert_equal opening, broken["prompt"]
    assert_equal "#{opening}\nYour last reply was rejected: the ```json block is missing. Write the whole reply again.", rewrite["prompt"],
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

  test "the narrator command narrates at no cost" do
    roll = play_first_scene
    resolve roll

    usages = @game_session.conversation.ruby_llm_usages
    assert_equal [ [ "openai", "gpt-5-nano" ] ], usages.pluck(:provider, :model).uniq
    assert_equal 2, usages.count
    assert_equal 0, @game_session.conversation.cost.total
  end

  private
    def opening
      "Scene 1 of 7, the story's first half, Ilker's turn. This is the opening, as the plan's opening has it: show where Ilker is and why, and the one or two people the plan's opening has Ilker meet, saying who they are, and end on the trouble landing on Ilker, so the reader knows what is at stake. Reveal nothing of what the plan hides: the people there believe what the plan says is believed, and no one's look or manner gives the hidden part away.\n#{sheet}"
    end

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
