require "test_helper"

class PartyPlayFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @room = game_sessions(:ilker_room)
  end

  test "two players take turns, each watching the other's scene" do
    first_scene = start_with(SCENE_RESPONSE).sole

    assert_includes first_scene["system"], "The party, who travel together and take turns:\n- Ilker: "
    assert_includes first_scene["system"], "\n- Deniz: "
    assert_includes first_scene["system"], 'Speak to the one whose turn it is as "you" and call the others by name'
    assert_equal <<~CUE, first_scene["prompt"]
      Scene 1 of 7, the story's first half, Ilker's turn. This is the opening, as the plan's opening has it: show where Ilker is and why, who is there and who they are, and end on the trouble landing on Ilker, so the reader knows what is at stake. Reveal nothing of what the plan hides.
      Ilker, human warrior (background: soldier): 31/31 health; carries Longsword, Round shield; no statuses.
      In the scene with Ilker: Deniz, human warrior (background: soldier), 31/31 health.
    CUE

    sign_in_as users(:ilker)
    get game_session_path(@room), as: :json
    game = response.parsed_body
    assert game["multiplayer"]
    assert game["your_turn"]
    assert_equal [ [ "Ilker", true ], [ "Deniz", false ] ], game["party"].map { it.values_at("name", "you") }
    assert_equal "Ilker", game["scenes"].sole["active_player"]

    sign_in_as users(:deniz)
    get game_session_path(@room), as: :json
    assert_not response.parsed_body["your_turn"]

    choice = @room.current_scene.choices.find_by!(stat: "strength")
    post game_session_choice_selection_path(@room, choice), as: :json
    assert_response :forbidden

    get game_session_path(@room)
    assert_select ".party__turn", text: "Ilker’s turn"
    assert_select ".watch", text: /Ilker is deciding/
    assert_select ".choice", count: 0

    sign_in_as users(:ilker)
    get game_session_path(@room)
    assert_select ".party__turn", text: "Ilker"
    assert_select ".choice", count: 3

    post game_session_choice_selection_path(@room, choice), as: :json
    assert_response :no_content

    sign_in_as users(:deniz)
    get game_session_path(@room)
    assert_select ".feed__action", text: /Force the drawer open/
    assert_select ".watch", text: /Ilker is rolling/
    assert_select ".d20", count: 0

    sign_in_as users(:ilker)
    outcome = stub_understudy(OUTCOME_RESPONSE) do
      perform_enqueued_jobs { post game_session_roll_path(@room), as: :json }
    end.sole
    assert_includes outcome["prompt"], "\nIn the scene with Ilker: Deniz, human warrior (background: soldier), 31/31 health.\n"

    sign_in_as users(:deniz)
    get game_session_path(@room)
    assert_select ".feed__resolution", text: "The drawer opens, but you cut your hand."
    assert_select ".watch", text: /Ilker is reading the outcome/

    sign_in_as users(:ilker)
    second_scene = stub_understudy(SECOND_SCENE_RESPONSE) do
      perform_enqueued_jobs { post game_session_acknowledgement_path(@room), as: :json }
    end.sole
    assert second_scene["prompt"].include?("\n\nScene 2 of 7, the story's first half, Deniz's turn. Pick up where the last outcome stopped, without retelling it. No clue found yet. The heroes do only what the players chose: where the way forks, the fork goes into the choices.\nDeniz, human warrior (background: soldier): ")
    assert_includes second_scene["prompt"], "<user>\nIn scene 1 of 7, the story's first half, Ilker chose \"Force the drawer open\""

    get game_session_path(@room), as: :json
    game = response.parsed_body
    assert_not game["your_turn"]
    assert_equal "Deniz", game["scenes"].last["active_player"]

    sign_in_as users(:deniz)
    get game_session_path(@room), as: :json
    assert response.parsed_body["your_turn"]

    choice = @room.current_scene.choices.find_by!(stat: "wisdom")
    post game_session_choice_selection_path(@room, choice), as: :json
    assert_response :no_content
  end

  test "solo play shows no party" do
    sign_in_as users(:ilker)
    game_sessions(:ilker_solo).advance
    game_sessions(:ilker_solo).current_scene.update! state: :choosing, title: "The Old Inn"

    get game_session_path(game_sessions(:ilker_solo))
    assert_select ".party", count: 0
    assert_select ".choice", count: 0
    assert_select ".action-panel"
  end

  private
    def start_with(*replies)
      [ users(:ilker), users(:deniz) ].each do |user|
        sign_in_as user
        post game_session_character_path(@room), params: { character: warrior }, as: :json
        assert_response :created
      end

      stub_understudy(*replies) do
        perform_enqueued_jobs { @room.start(by: players(:ilker_room_host)) }
      end
    end

    def warrior
      { race: "human", klass: "warrior", background: "soldier",
        stats: Character::Klass.fetch("warrior").base_stats.merge("strength" => 16, "constitution" => 15, "charisma" => 14) }
    end
end
