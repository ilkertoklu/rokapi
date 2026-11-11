require "test_helper"

class Narrator::PlannerTest < ActiveSupport::TestCase
  REWRITTEN_PLAN = "Question: Will the hero bring the boy home before the press gang sails?\n"

  setup do
    @game_session = game_sessions(:ilker_solo)
  end

  test "a plan the critic finds nothing wrong with is kept as written" do
    planner, critic = stub_llm(*PLANNING) { assert_equal PLAN_RESPONSE.strip, Narrator::Planner.for(@game_session).plan }

    assert_includes planner["system"], "- The place: A fog-bound fishing village\n"
    assert_includes planner["system"], "- What the story turns on: the one asking for help is the cause\n"
    assert_includes planner["system"], "- Ilker, human warrior (background: soldier)\n"
    assert_includes planner["system"], "Write the plan in English"
    assert_equal "Write the plan.", planner["prompt"]

    assert_includes critic["system"], "The hero: Ilker, human warrior (background: soldier)."
    assert_includes critic["system"], "A story too big for 7 scenes"
    assert_equal PLAN_RESPONSE.strip, critic["prompt"], "the critic reads the plan without the planner's conversation"
  end

  test "the planner is told what the players' latest stories hid, and a first story is told nothing" do
    planner, _ = stub_llm(*PLANNING) { Narrator::Planner.for(@game_session).plan }
    assert_not_includes planner["system"], "latest stories"

    GameSession.create!(creator: users(:ilker), card: "lighthouse_rock called_debt hiding_apprentice",
      plan: "**Question:** Will the debt be paid?\n\n**Opening:** A storm.\n\n**Believed:** The sea took the light.\n\n**Hidden:** The keeper slept and the light went out.\n\n**People:**\n- Edda")
    planner, _ = stub_llm(*PLANNING) { Narrator::Planner.for(@game_session).plan }
    assert_includes planner["system"], "The players' latest stories hid these pasts:\n- The keeper slept and the light went out.\nTell a story unlike them.\n\nWrite the plan"
  end

  test "a plan with problems is rewritten once, and no more" do
    passes = nil
    requests = stub_llm(PLAN_RESPONSE, "The plan has gaps:\n- The mother has no reason to beg for a search.\n", REWRITTEN_PLAN, "- The tide never matters.") do
      passes = Narrator::Planner.for(@game_session).passes
    end

    assert_equal [ PLAN_RESPONSE.strip, REWRITTEN_PLAN.strip ], passes.map(&:plan)
    assert_equal [ [ "The mother has no reason to beg for a search." ], [ "The tide never matters." ] ], passes.map(&:problems)

    rewrite = requests.third["prompt"]
    assert rewrite.start_with?("<conversation_so_far>\n<user>\nWrite the plan.\n</user>\n<assistant>\nQuestion: Will the hero find the lost child")
    assert rewrite.end_with?("A reader found these problems in the plan:\n- The mother has no reason to beg for a search.\nWrite the whole plan again with them fixed by cutting or simplifying, adding no new people, objects or past events, and reply with the plan only.")
    assert_equal 4, requests.size
  end

  test "an empty plan is malformed" do
    stub_llm("\n\n") do
      error = assert_raises(Narrator::MalformedResponse) { Narrator::Planner.for(@game_session).plan }
      assert_equal "the plan is empty", error.message
    end
  end

  test "the planner and the critic run on GPT-5.6" do
    assert_equal [ "gpt-5.6", "openai" ], Narrator::Planner.for(@game_session).chat.then { [ it.model_id, it.provider ] }
    assert_equal [ "gpt-5.6", "openai" ], Narrator::Critic.for(@game_session).chat.then { [ it.model_id, it.provider ] }
  end

  test "a plan can be rehearsed from cards without a game" do
    passes = nil
    planner, critic = stub_llm(*PLANNING) do
      assert_no_difference %w[ GameSession.count User.count Narrator::Conversation.count Narrator::Message.count RubyLLM::ActiveRecord::Usage.count ] do
        passes = Narrator::Planner.rehearse card: "snowbound_pass dry_well ambitious_clerk", twist: "both_hide_same", tone: "dark", length: "short", locale: "tr",
          heroes: [ { name: "İlker", race: "elf", klass: "mage", background: "criminal" } ]
      end
    end

    assert_equal [ [ PLAN_RESPONSE.strip, [] ] ], passes.map { [ it.plan, it.problems ] }
    assert_includes planner["system"], "- The place: A snowbound mountain pass with a single inn\n"
    assert_includes planner["system"], "The tone: dark; every win has a price.\nThe hero:\n- İlker, elf mage (background: criminal)\n"
    assert_includes planner["system"], "Write the plan in Türkçe"
    assert_equal GameSession::NAMES, (planner["system"][/^Names for anyone in the story who needs one: (.+)\.$/, 1].split(", ") & I18n.t("game_session.names", locale: :tr)).size
    assert_includes critic["system"], "The hero: İlker, elf mage (background: criminal)."
  end
end
