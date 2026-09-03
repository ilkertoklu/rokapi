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
    model = RubyLLM.models.find(call.model)
    assert_equal (1000 * model.input_price_per_million + 500 * model.output_price_per_million).round,
      call.cost_in_microdollars
    assert_operator call.cost_in_microdollars, :>, 0
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

    roll.acknowledge
    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }

    assert_equal 2, @game_session.scenes.count
    assert_equal "Ahır", @game_session.current_scene.title
    assert @game_session.current_scene.choosing?
  end

  test "outcome effects reach the inventory and the statuses" do
    character = characters(:ilker_hero)
    character.status_effects.create! name: "Yorgun", modifier: -1, expires_when: "dinlenene dek"
    roll = play_first_scene

    fake = FakeChat.new(%({"resolution": "Sandıkta bir merhem buldun ama sırılsıklam oldun.",
      "effects": {"hp": -2,
        "items_gained": [{"name": "Sarı merhem", "kind": "instant", "description": "", "hp": 5, "uses": 1}],
        "items_lost": ["Han defteri"],
        "statuses_gained": [{"name": "Sırılsıklam", "modifier": -2, "turns": 2, "expires_when": ""}],
        "statuses_lost": ["Yorgun"]}}))
    stub_llm(fake) { roll.narrate_outcome }

    assert_equal 31 - 2, character.reload.hp
    assert character.items.usable.exists?(name: "Sarı merhem")
    assert_not character.items.exists?(name: "Han defteri")
    assert_equal 2, character.status_effects.find_by!(name: "Sırılsıklam").turns_left
    assert_not character.status_effects.exists?(name: "Yorgun")
    assert_equal [ "Sarı merhem" ], roll.reload.items_gained.pluck("name")
    assert_equal [ "Sırılsıklam" ], roll.statuses_gained.pluck("name")
  end

  test "a positive status is earned only by a natural twenty" do
    stub_llm(FakeChat.new(SCENE_RESPONSE)) { narrate }
    boon = %({"resolution": "Kapı açıldı.", "effects": {"hp": 0,
      "statuses_gained": [{"name": "Sağlam Tutuş", "modifier": 2, "turns": 2, "expires_when": ""}]}})

    roll = roll_with(value: 19)
    stub_llm(FakeChat.new(boon)) { roll.narrate_outcome }
    assert_empty characters(:ilker_hero).status_effects, "a brilliant success must not stack a bonus"
    assert_empty roll.reload.statuses_gained

    roll.acknowledge
    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    roll = roll_with(value: 20)
    stub_llm(FakeChat.new(boon)) { roll.narrate_outcome }
    assert characters(:ilker_hero).status_effects.exists?(name: "Sağlam Tutuş")
  end

  test "a resolution may replace an item it takes away" do
    roll = play_first_scene

    fake = FakeChat.new(%({"resolution": "Şişen kırıldı ama enkazda yenisini buldun.",
      "effects": {"hp": 0,
        "items_gained": [{"name": "Şifa iksiri", "kind": "instant", "description": "", "hp": 6, "uses": 1}],
        "items_lost": ["Şifa iksiri"]}}))
    stub_llm(fake) { roll.narrate_outcome }

    potions = characters(:ilker_hero).items.usable.where(name: "Şifa iksiri")
    assert_equal 6, potions.sole.hp_effect, "the lost copy goes first so the replacement survives"
  end

  test "an outcome granting a nameless item is malformed" do
    roll = play_first_scene

    assert_no_difference -> { Item.count } do
      stub_llm(FakeChat.new(%({"resolution": "Bir şey buldun.",
        "effects": {"hp": 0, "items_gained": [{"name": "", "kind": "instant"}]}}))) do
        assert_raises(Narrator::MalformedResponse) { roll.narrate_outcome }
      end
    end

    assert_nil roll.reload.resolution
  end

  test "the narrator sees the inventory, the statuses and what was used" do
    characters(:ilker_hero).status_effects.create! name: "Kararlı", modifier: 1, turns_left: 2
    roll = play_first_scene
    items(:sifa_iksiri).use

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate_outcome }

    assert_includes fake.prompt, "ENVANTER:"
    assert_includes fake.prompt, "Uzun kılıç"
    assert_includes fake.prompt, "Han defteri (görev eşyası)"
    assert_not_includes fake.prompt, "Şifa iksiri (anında", "a spent item must drop out of the inventory"
    assert_includes fake.prompt, "STATÜ ETKİLERİ: Kararlı (+1 zar, 2 tur)"
    assert_includes fake.prompt, "KULLANILAN EŞYA: Şifa iksiri (+7 can)"
  end

  test "a used item is settled by the outcome and not raised again by the next scene" do
    roll = play_first_scene
    items(:sifa_iksiri).use
    resolve roll
    roll.acknowledge

    scene_call = FakeChat.new(SECOND_SCENE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_not_includes scene_call.prompt, "KULLANILAN EŞYA"
  end

  test "statuses weigh on the roll and wear off with it" do
    character = characters(:ilker_hero)
    character.status_effects.create! name: "Sırılsıklam", modifier: -2, turns_left: 1

    stub_llm(FakeChat.new(SCENE_RESPONSE)) { narrate }
    scene = @game_session.current_scene
    choice = scene.choices.find_by!(stat: "strength")
    choice.choose
    roll = choice.roll_dice(by: scene.active_player)

    assert_equal(-2, roll.status_modifier)
    assert_equal roll.value + 3 - 2, roll.total
    assert_equal roll.total >= roll.target, roll.success?

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate_outcome }

    assert_includes fake.prompt, "-2 (statü)"
    assert_empty character.status_effects.reload, "a one-turn status must not outlive its roll"
  end

  test "the outcome prompt carries the grade of the roll" do
    stub_llm(FakeChat.new(SCENE_RESPONSE)) { narrate }
    roll = roll_with(value: 20)

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate_outcome }

    assert_includes fake.prompt, "KRİTİK BAŞARI (doğal 20"
  end

  test "a deep miss reaches the narrator with its distance" do
    stub_llm(FakeChat.new(SCENE_RESPONSE)) { narrate }
    roll = roll_with(value: 2)

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate_outcome }

    assert_includes fake.prompt, "AĞIR BAŞARISIZLIK (hedefin 9 puan altında)"
  end

  test "a scene reusing a stat across choices is malformed" do
    doubled = SCENE_RESPONSE.sub('"stat": "intelligence"', '"stat": "strength"')

    stub_llm(FakeChat.new(doubled)) do
      assert_raises(Narrator::MalformedResponse) { narrate }
    end

    assert @game_session.scenes.sole.narrating?
  end

  test "the story bible is written before the first scene" do
    @game_session.update! story_bible: nil
    plan_call = FakeChat.new(PLAN_RESPONSE)
    scene_call = FakeChat.new(SCENE_RESPONSE)

    stub_llm(plan_call, scene_call) { narrate }

    assert_includes plan_call.prompt, "SAHNE SAYISI: 7"
    assert_includes plan_call.prompt, "Savaşçı"
    assert_equal "Nail Aral", @game_session.reload.story_bible.dig("antagonist", "name")
    assert_equal %w[plan scene], @game_session.llm_calls.order(:id).pluck(:purpose)
    assert @game_session.current_scene.choosing?
  end

  test "a bible that never arrives leaves the first scene unwritten" do
    @game_session.update! story_bible: nil

    stub_llm(FakeChat.new("Kitap yok.")) do
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
    assert_includes scene_call.prompt, "HİKÂYE KİTABI"
    assert_includes scene_call.prompt, "Nail Aral"
    assert_includes scene_call.prompt, "VURUŞ: Meydana kesik kayışlı katır dönüyor."
    assert_includes scene_call.prompt, "GİRİŞ:"
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

    assert_includes scene_call.prompt, "[1] Eski Han @ Akçabük"
    assert_includes scene_call.prompt, "[4] Ahır @ Akçabük"
    assert_includes scene_call.prompt, "Çekmece açıldı ama elini kestin."
    assert_includes scene_call.prompt, "VURUŞ: Köprü ayağındaki yarık görülüyor."
    assert_equal 4, scene_call.prompt.scan("→ Seçim:").size
    assert_empty @game_session.llm_calls.where(purpose: "repair")
  end

  test "the surprise adventure takes its name from the bible" do
    @game_session.update! adventure: nil
    assert_equal "Kayıp Kervan", @game_session.title

    @game_session.update! story_bible: nil
    assert_equal "Sürpriz macera", @game_session.title
  end

  test "the finale is told the tally of the dice" do
    play_and_continue

    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    roll = roll_with(value: 2)
    resolve roll
    roll.acknowledge
    @game_session.update! length: "short"
    @game_session.scenes.where(position: 2).update_all(position: @game_session.scene_budget)

    scene_call = FakeChat.new(FINALE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_match(/ZAR BİLANÇOSU: \d+ başarı, \d+ başarısızlık; doruk zarı AĞIR BAŞARISIZLIK/, scene_call.prompt)
    assert @game_session.reload.finished?
  end

  test "the easy and hard stats of recent scenes are steered away from" do
    play_and_continue

    scene_call = FakeChat.new(SECOND_SCENE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_includes scene_call.prompt, %(ÇEŞİTLİLİK: Son sahnelerin seçenekleri: "Tozlu defteri oku", "Çekmeceyi zorla", "Ahırı sessizce dinle".)
    assert_includes scene_call.prompt, "Kolay seçenek Zekâ, zor seçenek — statındaydı"
  end

  test "a downed character forces the defeat finale" do
    characters(:ilker_hero).update! hp: 0

    scene_call = FakeChat.new(FINALE_RESPONSE.sub('"outcome": "victory"', '"outcome": "defeat"'))
    stub_llm(scene_call) { narrate }

    assert_includes scene_call.prompt, "KARAKTER YIĞILDI"
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
    items(:sifa_iksiri).use
    roll = choose_and_roll(@game_session.current_scene)

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate_outcome }

    assert_includes fake.prompt, "EKSİK:"
  end

  test "the healing hint rests while the character stands strong" do
    play_and_continue
    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    items(:sifa_iksiri).use
    roll = choose_and_roll(@game_session.current_scene)

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate_outcome }

    assert_not_includes fake.prompt, "EKSİK:",
      "a healthy character early in the story must not spawn potions"
  end

  test "the healing hint pauses right after a find" do
    characters(:ilker_hero).update! hp: 5
    items(:sifa_iksiri).use
    roll = play_first_scene

    fake = FakeChat.new(%({"resolution": "Rafta bir tılsım buldun.",
      "effects": {"hp": 0, "items_gained": [{"name": "Eski tılsım", "kind": "quest", "description": "", "hp": 0, "uses": 0}]}}))
    stub_llm(fake) { roll.narrate_outcome }
    roll.acknowledge
    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    next_roll = choose_and_roll(@game_session.current_scene)

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { next_roll.narrate_outcome }

    assert_not_includes fake.prompt, "EKSİK:",
      "back-to-back finds cheapen the loot"
  end

  test "no healing hint while a potion is still carried" do
    play_and_continue
    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { narrate }
    roll = choose_and_roll(@game_session.current_scene)

    fake = FakeChat.new(OUTCOME_RESPONSE)
    stub_llm(fake) { roll.narrate_outcome }

    assert_not_includes fake.prompt, "EKSİK:"
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

    assert_match(/TEKRAR:.*Güç/, scene_call.prompt)
  end

  test "a badly wounded character earns a breather in the scene prompt" do
    characters(:ilker_hero).update! hp: 9
    play_and_continue

    scene_call = FakeChat.new(SECOND_SCENE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_includes scene_call.prompt, "AĞIR YARALI"
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

  test "an outcome with a blank resolution is malformed" do
    roll = play_first_scene

    stub_llm(FakeChat.new(%({"resolution": "", "effects": {"hp": -4}}))) do
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
    roll.acknowledge

    scene_call = FakeChat.new(FINALE_RESPONSE)
    stub_llm(scene_call) { narrate }

    assert_includes scene_call.prompt, "FİNAL"
    assert @game_session.reload.finished?
  end

  private
    def narrate
      Narrator.new(@game_session).continue
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
      roll.acknowledge
      roll
    end

    def choose_and_roll(scene)
      choice = scene.choices.first
      choice.choose
      choice.roll_dice(by: scene.active_player)
    end

    def roll_strength(scene)
      choice = scene.choices.find_by!(stat: "strength")
      choice.choose
      choice.roll_dice(by: scene.active_player)
    end

    def roll_with(value:)
      scene = @game_session.current_scene
      choice = scene.choices.find_by!(stat: "strength")
      choice.choose
      scene.played!
      choice.create_roll! player: scene.active_player, value: value, modifier: choice.modifier,
        status_modifier: 0, target: choice.difficulty
    end

    def build_roll
      scene = @game_session.scenes.create! position: @game_session.scene_budget + 10,
        active_player: players(:ilker_solo_host), state: :choosing, title: "Ara"
      choice = scene.choices.create! label: "Devam", stat: "strength", modifier: 3,
        difficulty: 12, difficulty_label: "orta"
      choice.choose
      choice.roll_dice(by: players(:ilker_solo_host))
    end
end
