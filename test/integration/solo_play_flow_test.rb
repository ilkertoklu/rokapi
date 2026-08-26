require "test_helper"

class SoloPlayFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    sign_in_as users(:sevval)
  end

  test "playing a solo adventure from setup to victory" do
    game_session = nil

    stub_llm(FakeChat.new(PLAN_RESPONSE), FakeChat.new(SCENE_RESPONSE)) do
      perform_enqueued_jobs { game_session = start_playing }
    end

    get game_session_path(game_session)
    assert_response :success
    assert_select ".location h1", text: "Eski Han"
    assert_select ".location p", text: "Akçabük · 1. durak"
    assert_select ".progress__dot--current", count: 1
    assert_select ".narration__body", text: /Yağmur hanın kiremitlerini/
    assert_select ".action-panel__prompt", text: "Sıra sende"
    assert_select ".choice__label", text: "Çekmeceyi zorla"
    assert_select ".character-button span", text: "Karakterim"

    choice = game_session.current_scene.choices.find_by!(stat: "strength")
    post game_session_chosen_choice_path(game_session, choice_id: choice.id)

    get game_session_path(game_session)
    assert_select ".dice__prompt", text: choice.label
    assert_select ".d20__value", text: "?"
    assert_select ".dice__facts dd", text: /Hedef #{choice.difficulty}/

    stub_llm(FakeChat.new(OUTCOME_RESPONSE)) do
      perform_enqueued_jobs { post game_session_roll_path(game_session) }
    end

    get game_session_path(game_session)
    assert_select ".outcome__verdict", text: /BAŞARI|FELAKET/
    assert_select ".outcome__resolution", text: "Çekmece açıldı ama elini kestin."
    assert_equal 1, game_session.scenes.count, "the story must not run ahead of the player"

    stub_llm(FakeChat.new(FINALE_RESPONSE)) do
      perform_enqueued_jobs { post game_session_acknowledgement_path(game_session) }
    end

    assert game_session.reload.finished?
    assert game_session.outcome_victory?

    get game_session_path(game_session)
    assert_select ".finale__outcome", text: "Zafer"
    assert_select ".highlights", text: /Zar atıldı/
    assert_select "[data-controller=share][data-share-text-value*=?]", "Dönüş — Zafer"
    assert_select "[data-share-text-value*=?]", "Kayıp Kervan"
    assert_equal %w[plan scene outcome scene], game_session.llm_calls.order(:id).pluck(:purpose)
    assert_operator game_session.llm_calls.sum(:cost_in_microdollars), :>, 0
  end

  test "the scene keeps its layout when the narrator stops writing" do
    game_session = start_playing
    scene = game_session.scenes.create! position: 1, active_player: game_session.players.sole,
      state: :narrating, title: "Eski Han", narration: "Yağmur."

    get game_session_path(game_session)
    assert_select ".writing", 1
    while_writing = above_the_narration

    scene.update! state: :choosing

    get game_session_path(game_session)
    assert_equal while_writing, above_the_narration,
      "nothing may appear above the text when writing ends, or the reader loses their place"
    assert_select "details.action-panel:not([open])", 1,
      "the panel must arrive collapsed so the reader keeps their place"
    assert_select ".action-panel__prompt", text: "Sıra sende"
  end

  test "the die rolls to rest on the value while the narrator writes" do
    game_session = play_to_choices

    choice = game_session.current_scene.choices.find_by!(stat: "strength")
    post game_session_chosen_choice_path(game_session, choice_id: choice.id)
    post game_session_roll_path(game_session)
    value = game_session.rolls.sole.value

    get game_session_path(game_session)
    assert_select ".d20__strip span:last-child", text: value.to_s,
      message: "the reel must come to rest on the value that was actually rolled"
    assert_select ".d20__value", count: 0
    assert_select ".writing", text: /Anlatıcı sonucu yazıyor/
    assert_select ".narration", count: 0

    stub_llm(FakeChat.new(OUTCOME_RESPONSE)) { perform_enqueued_jobs }

    get game_session_path(game_session)
    assert_select ".d20__strip", count: 0, message: "the outcome shows the rested die, it does not re-roll"
    assert_select ".d20__value", text: value.to_s
    assert_select ".outcome__verdict"
  end

  test "the next scene starts only once the outcome is acknowledged" do
    game_session = play_to_choices

    choice = game_session.current_scene.choices.find_by!(stat: "strength")
    post game_session_chosen_choice_path(game_session, choice_id: choice.id)

    stub_llm(FakeChat.new(OUTCOME_RESPONSE)) do
      perform_enqueued_jobs { post game_session_roll_path(game_session) }
    end

    get game_session_path(game_session)
    assert_select ".outcome__resolution", text: "Çekmece açıldı ama elini kestin."
    assert_select ".outcome__effect", text: "-4 Can"
    assert_select ".action-panel", count: 0
    assert_equal 1, game_session.scenes.count
    assert_equal %w[plan scene outcome], game_session.llm_calls.order(:id).pluck(:purpose)

    post game_session_acknowledgement_path(game_session)
    get game_session_path(game_session)
    assert_select ".outcome", count: 0
    assert_select ".writing", text: /Anlatıcı sahneyi yazıyor/, message: "no dead screen while the scene starts"

    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) { perform_enqueued_jobs }

    get game_session_path(game_session)
    assert_select ".location p", text: /2\. durak/
    assert_select ".action-panel__prompt", text: "Sıra sende"
  end

  test "a stalled outcome can be sent back to the narrator" do
    game_session = play_to_choices

    choice = game_session.current_scene.choices.find_by!(stat: "strength")
    post game_session_chosen_choice_path(game_session, choice_id: choice.id)
    post game_session_roll_path(game_session)
    clear_enqueued_jobs
    game_session.rolls.sole.stall_narration

    get game_session_path(game_session)
    assert_select ".stalled"
    assert_select ".d20__strip", count: 0

    stub_llm(FakeChat.new(OUTCOME_RESPONSE)) do
      perform_enqueued_jobs { post game_session_narration_path(game_session) }
    end

    assert game_session.rolls.sole.reload.resolved?
    get game_session_path(game_session)
    assert_select ".outcome__verdict"
  end

  test "a stalled narrator can be sent back to work" do
    game_session = start_playing
    clear_enqueued_jobs
    game_session.scenes.create! position: 1, active_player: game_session.players.sole, state: :failed

    get game_session_path(game_session)
    assert_select ".stalled"

    stub_llm(FakeChat.new(PLAN_RESPONSE), FakeChat.new(SCENE_RESPONSE)) do
      perform_enqueued_jobs do
        post game_session_narration_path(game_session)
      end
    end

    assert game_session.current_scene.choosing?
    assert_equal 1, game_session.scenes.count
  end

  test "a lost narration job can be nudged back to work" do
    game_session = play_to_choices
    choice = game_session.current_scene.choices.find_by!(stat: "strength")
    post game_session_chosen_choice_path(game_session, choice_id: choice.id)
    stub_llm(FakeChat.new(OUTCOME_RESPONSE)) do
      perform_enqueued_jobs { post game_session_roll_path(game_session) }
    end
    post game_session_acknowledgement_path(game_session)
    clear_enqueued_jobs

    get game_session_path(game_session)
    assert_select ".overdue form[action=?]", game_session_narration_path(game_session)

    stub_llm(FakeChat.new(SECOND_SCENE_RESPONSE)) do
      perform_enqueued_jobs { post game_session_narration_path(game_session) }
    end

    assert_equal 2, game_session.scenes.count
    assert game_session.current_scene.choosing?
  end

  test "a nudge while the narrator is writing does not double the work" do
    game_session = play_to_choices
    game_session.current_scene.narrating!

    assert_no_enqueued_jobs only: Scene::GenerateJob do
      post game_session_narration_path(game_session)
    end

    assert_redirected_to game_session_path(game_session)
  end

  test "rolling out of turn does not blow up" do
    game_session = play_to_choices
    assert game_session.current_scene.choosing?

    post game_session_roll_path(game_session)
    assert_redirected_to game_session_path(game_session)
    assert_empty game_session.rolls
  end

  test "the same choice cannot be taken twice" do
    game_session = play_to_choices
    choice = game_session.current_scene.choices.first

    post game_session_chosen_choice_path(game_session, choice_id: choice.id)
    post game_session_chosen_choice_path(game_session, choice_id: choice.id)
    assert_redirected_to game_session_path(game_session)

    assert_equal 1, game_session.current_scene.choices.chosen.count
  end

  test "players cannot act on a foreign session" do
    game_session = game_sessions(:ilker_solo)
    scene = game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host),
      state: :choosing, title: "Eski Han"
    choice = scene.choices.create! label: "Defteri oku", stat: "intelligence",
      modifier: -1, difficulty: 10, difficulty_label: "kolay"

    post game_session_chosen_choice_path(game_session, choice_id: choice.id)
    assert_response :not_found

    post game_session_roll_path(game_session)
    assert_response :not_found
  end

  private
    def above_the_narration
      Nokogiri::HTML5(response.body).at("#game_stage").element_children
        .take_while { |element| element["class"].to_s.exclude?("narration") }
        .map { |element| element["class"] }
    end

    def start_playing
      post game_sessions_path, params: {
        game_session: { adventure_id: adventures(:kayip_kervan).id, tone: "balanced", length: "short" }
      }
      game_session = users(:sevval).game_sessions.sole

      post game_session_character_path(game_session), params: {
        character: { race: "elf", klass: "warrior", background: "traveler",
                     stats: Character.base_stats_for("warrior").merge("strength" => 16, "constitution" => 15, "charisma" => 14) }
      }

      game_session
    end

    def play_to_choices
      start_playing.tap do |game_session|
        stub_llm(FakeChat.new(PLAN_RESPONSE), FakeChat.new(SCENE_RESPONSE)) { perform_enqueued_jobs }
        assert game_session.current_scene.choosing?
      end
    end
end
