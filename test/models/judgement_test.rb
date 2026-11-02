require "test_helper"

class JudgementTest < ActiveSupport::TestCase
  VERDICT = %({"better": "second", "confidence": "high", "reason": "The stable pays off the ledger.", "improvement": "Let the drawer matter later."})

  setup do
    @inn = finish game_sessions(:ilker_solo), narration: "Rain hammers the inn's roof tiles.", choice: "Force the drawer open", ending: "victory"
    @stable = finish game_sessions(:deniz_solo), narration: "The stable door is barred from the inside.", choice: "Lift the bar", ending: "defeat"
  end

  test "the verdict names the game the judge preferred, whichever way round it was shown" do
    judge = FakeChat.new(VERDICT)

    verdict = stub_llm(judge) { Judgement.new(@inn, @stable).verdict }
    assert_equal [ @inn.id, @stable.id, @stable.id, @inn.id ], verdict.values_at("first", "second", "winner", "loser")
    assert_equal "high", verdict["confidence"]
    assert_equal "The stable pays off the ledger.", verdict["reason"]
    assert_equal "Let the drawer matter later.", verdict["improvement"]

    swapped = stub_llm(judge) { Judgement.new(@stable, @inn).verdict }
    assert_equal [ @stable.id, @inn.id, @inn.id ], swapped.values_at("first", "second", "winner")
  end

  test "the judge reads both stories in the order shown and never which game is which" do
    judge = FakeChat.new(VERDICT)
    stub_llm(judge) { Judgement.new(@stable, @inn).verdict }

    assert_operator judge.prompt.index("The stable door is barred"), :<, judge.prompt.index("Rain hammers the inn's")
    [ @inn, @stable ].each { |game| assert_not_includes judge.prompt, game.id.to_s }
    assert_includes judge.instructions, "editor of interactive fiction"
  end

  test "choices, rolls and outcomes are part of the story" do
    judge = FakeChat.new(VERDICT)
    stub_llm(judge) { Judgement.new(@inn, @stable).verdict }

    assert_includes judge.prompt, "- Read the dusty ledger (Intelligence, target 10)"
    assert_includes judge.prompt, "Chosen: Force the drawer open. Rolled 15 +3 = 18 against 14: success."
    assert_includes judge.prompt, "The drawer opens, but you cut your hand.\n(health -4)"
    assert_includes judge.prompt, "THE END: victory"
    assert_includes judge.prompt, "THE END: defeat"
  end

  test "the development judge runs on the narrator's command" do
    verdict = stub_understudy(VERDICT) { Judgement.new(@inn, @stable).verdict }

    assert_equal @stable.id, verdict["winner"]
  end

  test "a verdict without a pick is refused" do
    assert_raises Judgement::MalformedVerdict do
      stub_llm(FakeChat.new(%({"reason": "Both are fine."}))) { Judgement.new(@inn, @stable).verdict }
    end
  end

  private
    def finish(game, narration:, choice:, ending:)
      player = game.host
      game.update! started_at: 1.hour.ago

      opening = game.scenes.create! position: 1, active_player: player, state: :played, title: "The Old Inn", location: "Whitebend", narration: narration
      chosen = opening.choices.create! label: choice, stat: "strength", modifier: 3, target: 14, chosen_at: Time.current
      opening.choices.create! label: "Read the dusty ledger", stat: "intelligence", modifier: -1, target: 10
      opening.choices.create! label: "Listen at the stable", stat: "wisdom", modifier: 1, target: 12
      chosen.create_roll!(player: player, value: 15, status_modifier: 0)
        .resolve resolution: "The drawer opens, but you cut your hand.", effects: { "hp" => -4 }

      game.scenes.create! position: 2, active_player: player, state: :played, title: "The Return", location: "Whitebend",
        narration: "Snow settles over the square.", finale: true
      game.update! outcome: ending
      game.finish
      game
    end
end
