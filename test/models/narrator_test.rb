require "test_helper"
require "turbo/broadcastable/test_helper"

class NarratorTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    @game_session = game_sessions(:ilker_solo)
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
    assert_equal "Eski Han", scene.title
    assert_includes scene.narration, "Yağmur hanın kiremitlerini"
    assert_not_includes scene.narration, "```"

    assert_equal 3, scene.choices.count
    assert_equal(-1, scene.choices.find_by(stat: "intelligence").modifier)
    assert_equal 3, scene.choices.find_by(stat: "strength").modifier
    assert_equal 1, scene.choices.find_by(stat: "wisdom").modifier

    call = @game_session.llm_calls.sole
    assert_equal "scene", call.purpose
    expected = RubyLLM.models.find(call.model).cost_for(RubyLLM::Tokens.build(input: 1000, output: 500))
    assert_equal (expected.total.to_f * 1_000_000).round, call.cost_in_microcents
    assert_operator call.cost_in_microcents, :>, 0
  end

  test "the stage lands on screen before narration streams into it" do
    fake = FakeChat.new(SCENE_RESPONSE, chunks: SCENE_RESPONSE.chars.each_slice(40).map(&:join))

    streams = stub_llm(fake) do
      capture_turbo_stream_broadcasts(@game_session) { narrate }
    end

    assert_equal "replace", streams.first["action"]
    assert_equal "game_stage", streams.first["target"]
    assert_equal "morph", streams.first["method"], "stage swaps restart in-flight animations"

    assert_operator streams.index { |stream| stream["target"] == "scene_narration" },
      :>, 0, "narration streamed before the stage was on screen"
    assert_equal "game_stage", streams.last["target"]
  end

  test "the outcome is written by its own call, without touching the story" do
    roll = play_first_scene
    assert_nil roll.resolution

    resolve roll

    assert_equal "Çekmece açıldı ama elini kestin.", roll.reload.resolution
    assert_equal 31 - 4, characters(:ilker_hero).reload.hp
    assert_equal 1, @game_session.scenes.count, "the outcome call must not write a scene"
    assert_equal "outcome", @game_session.llm_calls.outcome.sole.purpose
  end

  test "resolving a roll puts the outcome on screen" do
    roll = play_first_scene

    streams = capture_turbo_stream_broadcasts(@game_session) { resolve roll }

    assert_equal 1, streams.size, "the spinning die never stops without a stage broadcast"
    assert_equal "game_stage", streams.first["target"]
  end

  test "the next scene is not written until the player continues" do
    roll = play_first_scene
    resolve roll

    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    assert_equal 1, @game_session.scenes.count, "the narrator must idle while the outcome is unread"

    roll.acknowledge!
    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }

    assert_equal 2, @game_session.scenes.count
    assert_equal "Ahır", @game_session.current_scene.title
    assert @game_session.current_scene.choosing?
  end

  test "an unresolved roll is never resolved twice" do
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
    stub_llm(FakeChat.new("Anlatı geldi ama yapı yok."), FakeChat.new(SCENE_RESPONSE)) do
      assert_raises Narrator::MalformedResponse do
        narrate
      end
      assert @game_session.scenes.sole.narrating?

      narrate
    end

    scene = @game_session.scenes.sole
    assert scene.choosing?
    assert_equal "Eski Han", scene.title
    assert_equal 3, scene.choices.count
  end

  test "an outcome without a resolution is malformed" do
    roll = play_first_scene

    stub_llm(FakeChat.new(%(```json\n{"effects": {"hp": -4}}\n```))) do
      assert_raises Narrator::MalformedResponse do
        roll.narrate_outcome
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

  test "malformed structure block raises after a failed repair" do
    stub_llm(FakeChat.new("Anlatı geldi ama yapı yok. ```json {bozuk``` ")) do
      assert_raises Narrator::MalformedResponse do
        narrate
      end
    end
  end

  test "the final scene is demanded when the budget is spent" do
    @game_session.update! length: "short"
    (1...@game_session.scene_budget).each do |position|
      @game_session.scenes.create! position: position, active_player: players(:ilker_solo_host),
        state: :played, title: "Sahne #{position}", narration: "Olaylar."
    end
    roll = build_roll
    resolve roll
    roll.acknowledge!

    scene_call = FakeChat.new(FINALE_RESPONSE)
    stub_llm(scene_call, FakeChat.new("özet")) { narrate }

    assert_includes scene_call.prompt, "FİNAL"
    assert @game_session.reload.finished?
  end

  test "each scene ages out of the recent window exactly once" do
    play_and_continue

    4.times do
      stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
      roll = choose_and_roll(@game_session.current_scene)
      resolve roll
      roll.acknowledge!
    end

    assert_equal 3, @game_session.reload.context_summary_position
    assert_equal 3, @game_session.llm_calls.summary.count
  end

  test "summarising never delays the scene the player is waiting for" do
    play_and_continue
    3.times do
      stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
      roll = choose_and_roll(@game_session.current_scene)
      resolve roll
      roll.acknowledge!
    end
    summaries_before = @game_session.llm_calls.summary.count
    assert_operator summaries_before, :>, 0, "the fixture must be deep enough to summarise"

    seen = []
    fake = FakeChat.split_at_structure(SECOND_SCENE_RESPONSE) do
      seen << { scenes: @game_session.scenes.count, summaries: @game_session.llm_calls.summary.count }
    end

    stub_llm(fake) { narrate }

    assert_equal @game_session.scenes.count, seen.first[:scenes],
      "the scene row must exist before the narrator starts writing"
    assert_equal summaries_before, seen.first[:summaries],
      "summarising must not run ahead of the scene the player is waiting for"
    assert_operator @game_session.llm_calls.summary.count, :>, summaries_before
  end

  private
    def narrate
      Narrator.new(@game_session).continue!
    end

    def resolve(roll)
      stub_llm(FakeChat.new(OUTCOME_RESPONSE)) { roll.narrate_outcome }
    end

    def play_first_scene
      stub_llm(FakeChat.new(SCENE_RESPONSE)) { narrate }
      choose_and_roll @game_session.current_scene
    end

    def play_and_continue
      roll = play_first_scene
      resolve roll
      roll.acknowledge!
      roll
    end

    def choose_and_roll(scene)
      choice = scene.choices.first
      choice.choose!
      choice.roll!(by: scene.active_player)
    end

    def build_roll
      scene = @game_session.scenes.create! position: @game_session.scene_budget + 10,
        active_player: players(:ilker_solo_host), state: :choosing, title: "Ara"
      choice = scene.choices.create! label: "Devam", stat: "strength", modifier: 3,
        difficulty: 12, difficulty_label: "orta"
      choice.choose!
      choice.roll!(by: players(:ilker_solo_host))
    end
end
