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

    usage = @game_session.conversation.ruby_llm_usages.sole
    model = RubyLLM.models.find(usage.model)
    assert_equal [ 1000, 500 ], [ usage.input_tokens, usage.output_tokens ]
    assert_in_delta (1000 * model.price(:input) + 500 * model.price(:output)) / 1_000_000, @game_session.conversation.cost.total
    assert_operator @game_session.conversation.cost.total, :>, 0
  end

  test "the narration streams in before the stage refreshes with the title and the choices" do
    fake = FakeReply.new(SCENE_RESPONSE, chunks: SCENE_RESPONSE.chars.each_slice(40).map(&:join))

    streams = stub_llm(fake) do
      capture_turbo_stream_broadcasts(@game_session) { narrate }
    end

    assert_equal "scene_narration", streams.first["target"], "the first words reach the screen before any refresh"
    assert_equal "refresh", streams.last["action"], "the title and the choices arrive with a final refresh"
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

    stub_llm(FakeReply.new(SECOND_SCENE_RESPONSE)) { narrate }
    assert_equal 1, @game_session.scenes.count, "the narrator must idle while the outcome is unread"

    roll.acknowledge
    stub_llm(FakeReply.new(SECOND_SCENE_RESPONSE)) { narrate }

    assert_equal 2, @game_session.scenes.count
    assert_equal "The Stable", @game_session.current_scene.title
    assert @game_session.current_scene.choosing?
  end

  test "the brief carries the party, and a roll carries what was used" do
    roll = play_first_scene
    items(:healing_potion).use

    fake = FakeReply.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate }

    assert_includes fake.instructions, "Sets out with Longsword; Round shield."
    assert_equal <<~CUE, fake.prompt
      Ilker chose "#{roll.choice.label}": die 2, modifier #{format("%+d", roll.modifier)}, statuses +0, total #{roll.total} against #{roll.target}. #{roll.grade_label}, margin #{format("%+d", roll.margin)}.
      Used since the scene began, already applied: Healing potion (+7 health).
      Ilker has 31/31 health.
    CUE
  end

  test "a used item is settled by the outcome and not raised again by the next scene" do
    roll = play_first_scene
    items(:healing_potion).use
    resolve roll
    roll.acknowledge

    scene_call = FakeReply.new(SECOND_SCENE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_equal "Scene 2 of 7, Ilker's turn.\n", scene_call.prompt
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

    assert_includes fake.prompt, "statuses -2, total #{roll.total}"
    assert_empty character.status_effects.reload, "a one-turn status must not outlive its roll"
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

  test "the brief opens one conversation for the whole game" do
    first = FakeReply.new(SCENE_RESPONSE)
    stub_llm(first) { narrate }

    assert_equal [ :user ], first.conversation.map(&:role)
    assert_includes first.instructions, "Length: 7 scenes"
    assert_includes first.instructions, "Quest: The caravan carrying Whitebend's winter salt"
    assert_includes first.instructions, "Warrior"
    assert_equal "Scene 1 of 7, Ilker's turn. This is the first scene.\n", first.prompt

    roll = with_die(2) { choose_and_roll @game_session.current_scene }
    outcome = FakeReply.new(OUTCOME_RESPONSE)
    stub_llm(outcome) { roll.narrate }
    roll.acknowledge
    second = FakeReply.new(SECOND_SCENE_RESPONSE)
    stub_llm(second) { narrate }

    assert_equal 1, Narrator::Conversation.where(game_session: @game_session).count
    assert_equal first.instructions, second.instructions, "the brief never changes, so the cache holds"
    assert_equal %i[user assistant user assistant user], second.conversation.map(&:role)
    assert_includes second.conversation[1].content, "Rain hammers the inn's roof tiles"
    assert_equal "The drawer opens, but you cut your hand.", JSON.parse(second.conversation[3].content)["resolution"]
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

    assert_equal 2 * 8 + 1, scene_call.conversation.size
    assert_equal "Scene 5 of 7, Ilker's turn.\n", scene_call.prompt
    assert_equal 1, scene_call.messages.count { |message| message.role == :system }
  end

  test "a turn the provider never answered is answered on the next attempt" do
    stub_llm(FakeReply.failing(RubyLLM::ServerError.new("overloaded"))) do
      assert_raises(RubyLLM::ServerError) { narrate }
    end

    retry_call = FakeReply.new(SCENE_RESPONSE)
    stub_llm(retry_call) { narrate }

    assert @game_session.current_scene.choosing?
    assert_equal %i[user], retry_call.conversation.map(&:role), "the turn is not asked twice"
  end

  test "the brief of an English game" do
    scene_call = FakeReply.new(SCENE_RESPONSE)

    stub_llm(scene_call) { narrate }

    assert_equal <<~BRIEF, scene_call.instructions[/\A.*(?=EACH TURN)/m]
      You narrate Rokapi, a tabletop adventure played on a phone with a d20. Everything the players see is written in English, for ages 12 and up.

      THIS GAME
      Quest: The caravan carrying Whitebend's winter salt has been missing for three days. It has to be found and brought to the village before the blizzard closes the pass. The route runs from Whitebend to Blizzard Pass, on past the tracks, the abandoned lodges and the rope bridge at the pass. The caravan's loss could be an accident, or it could be an ambush.
      Tone: Balanced
      Length: 7 scenes; the last one is the finale.
      The character:
      - Ilker: Human (Versatile and balanced, at home in any class.), Warrior (Fights at the front, starts with a longsword and a round shield.), Soldier (Discipline, and the sight of war.). Health 31. Strength 16, Agility 11, Constitution 15, Intelligence 8, Wisdom 12, Charisma 14. Sets out with Longsword; Round shield.

    BRIEF
  end

  test "the brief of a Turkish game, read in the default locale like the narration job" do
    @game_session.update! locale: "tr"
    scene_call = FakeReply.new(SCENE_RESPONSE)

    stub_llm(scene_call) { narrate }

    assert_equal <<~BRIEF, scene_call.instructions[/\A.*(?=EACH TURN)/m]
      You narrate Rokapi, a tabletop adventure played on a phone with a d20. Everything the players see is written in Turkish, for ages 12 and up.

      THIS GAME
      Quest: Akçabük köyünün kış tuzunu getiren kervan üç gündür kayıp. Boran geçidi kapatmadan kervanı bulup köye ulaştırmak gerekiyor. Rota Akçabük'ten Boranlı Geçit'e uzanıyor; izler, terk edilmiş konaklar ve geçitteki asma köprü üzerinden ilerliyor. Kervanın kaybı bir kaza da olabilir, bir pusu da.
      Tone: Balanced
      Length: 7 scenes; the last one is the finale.
      The character:
      - Ilker: Human (Versatile and balanced, at home in any class.), Warrior (Fights at the front, starts with a longsword and a round shield.), Soldier (Discipline, and the sight of war.). Health 31. Strength 16, Agility 11, Constitution 15, Intelligence 8, Wisdom 12, Charisma 14. Sets out with Uzun kılıç; Yuvarlak kalkan.

    BRIEF
    assert_equal "Scene 1 of 7, Ilker's turn. This is the first scene.\n", scene_call.prompt
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

    assert_equal "Scene 1 of 7, Ilker's turn. Ilker has collapsed, their health spent: this scene is the finale, in defeat.\n", scene_call.prompt
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
    assert_equal 2, @game_session.conversation.ruby_llm_usages.count, "one scene and one outcome"
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

  test "a finale without a known outcome is malformed" do
    play_and_continue

    stub_llm(FakeReply.new(FINALE_RESPONSE.sub('"outcome": "victory"', '"outcome": "belirsiz"'))) do
      assert_raises Narrator::MalformedResponse do
        narrate
      end
    end

    assert_not @game_session.reload.finished?
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

    assert_match(/This scene is the finale.\n\z/, scene_call.prompt)
    assert @game_session.reload.finished?
  end

  test "a reply that breaks a rule is rewritten with the reason" do
    out_of_range = SCENE_RESPONSE.sub('"difficulty": 14', '"difficulty": 25')
    broken = FakeReply.new(out_of_range)
    rewrite = FakeReply.new(SCENE_RESPONSE)

    stub_llm(broken, rewrite) { narrate }

    assert @game_session.scenes.sole.choosing?
    assert_equal "Scene 1 of 7, Ilker's turn. This is the first scene.\n", broken.prompt
    assert_equal "Scene 1 of 7, Ilker's turn. This is the first scene.\n\nYour last reply was rejected: difficulty 25 is outside 8-19. Write the whole reply again.", rewrite.prompt
    assert_equal %i[user], rewrite.conversation.map(&:role), "the rejected reply is not in the conversation the rewrite sees"

    messages = @game_session.conversation.messages.reload
    assert_equal %w[system user assistant], messages.pluck(:role)
    assert_equal rewrite.prompt, messages.second.content, "the reason stays in the transcript"
    assert_equal 2, @game_session.conversation.ruby_llm_usages.count, "both calls are still paid for"
  end

  test "a reply that keeps breaking the rules is given up after the rewrites, leaving no trace" do
    broken = FakeReply.new(SCENE_RESPONSE.sub('"difficulty": 14', '"difficulty": 25'))

    stub_llm(broken) do
      error = assert_raises(Narrator::MalformedResponse) { narrate }
      assert_equal "difficulty 25 is outside 8-19", error.message
    end

    assert_equal 1 + Narrator::REWRITES, @game_session.conversation.ruby_llm_usages.count
    assert_equal %w[system], @game_session.conversation.messages.reload.pluck(:role)
    assert @game_session.scenes.sole.narrating?
  end

  test "a scene without its fence is malformed" do
    unfenced = SCENE_RESPONSE.delete("`").sub("json\n", "")

    stub_llm(FakeReply.new(unfenced)) do
      error = assert_raises(Narrator::MalformedResponse) { narrate }
      assert_equal "the ```json block is missing", error.message
    end

    assert @game_session.scenes.sole.narrating?
  end

  test "a broken structure block is malformed" do
    stub_llm(FakeReply.new("Prose arrived. ```json {broken``` ")) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert @game_session.scenes.sole.narrating?
  end

  test "the finale's closing words stream in before the game is closed" do
    play_and_continue
    finale = @game_session.current_scene
    staged = []

    fake = FakeReply.split_before_structure(FINALE_RESPONSE) do
      staged << [ finale.reload.narration, finale.finale?, @game_session.reload.outcome ]
    end
    stub_llm(fake) { narrate }

    assert_equal [ "The caravan bells echo down the valley as you ride into Whitebend.", false, nil ], staged.first
    assert finale.reload.finale?
    assert @game_session.reload.outcome_victory?
  end

  test "a scene that does not fit the screen is rewritten until the narrator gives up" do
    long = "word " * 20
    { "the narration" => "#{"Snow falls. " * 50}\n\n" + SCENE_RESPONSE,
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

  test "a resolution that does not fit the screen is rewritten" do
    roll = play_first_scene
    long = FakeReply.new(%({"resolution": "#{"The drawer sticks. " * 20}", "effects": {"hp": 0}}))

    stub_llm(long, FakeReply.new(OUTCOME_RESPONSE)) { roll.narrate }

    assert_equal "The drawer opens, but you cut your hand.", roll.reload.resolution
    assert_equal 1 + 2, @game_session.conversation.ruby_llm_usages.count, "the scene, the rejected outcome and its rewrite"
  end

  test "the understudy writes a scene at no cost" do
    stub_understudy(SCENE_RESPONSE) { narrate }

    scene = @game_session.scenes.sole
    assert scene.choosing?
    assert_equal "The Old Inn", scene.title
    assert scene.narration.start_with?("Rain hammers")
    assert_equal 3, scene.choices.count

    usage = @game_session.conversation.ruby_llm_usages.sole
    assert_equal [ "understudy", "understudy" ], [ usage.provider, usage.model ]
    assert_equal 0, @game_session.conversation.cost.total
  end

  test "the understudy resolves a roll at no cost" do
    stub_understudy(SCENE_RESPONSE) { narrate }
    roll = with_die(2) { choose_and_roll @game_session.current_scene }

    stub_understudy(OUTCOME_RESPONSE) { roll.narrate }

    assert_equal "The drawer opens, but you cut your hand.", roll.reload.resolution
    assert_equal 2, @game_session.conversation.ruby_llm_usages.count
    assert_equal 0, @game_session.conversation.cost.total
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
