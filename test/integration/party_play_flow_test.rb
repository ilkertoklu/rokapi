require "test_helper"

class PartyPlayFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @room = game_sessions(:ilker_room)
  end

  test "two players take turns, each watching the other's scene" do
    first_scene = start_with(SCENE_RESPONSE).sole

    assert_includes first_scene["system"], "The party, taking turns:\n- Ilker: "
    assert_includes first_scene["system"], "\n- Deniz: "
    assert_equal "Scene 1 of 7, Ilker's turn. Open the story in motion and decide the secret.\n", first_scene["prompt"]

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
    stub_understudy(OUTCOME_RESPONSE) do
      perform_enqueued_jobs { post game_session_roll_path(@room), as: :json }
    end

    sign_in_as users(:deniz)
    get game_session_path(@room)
    assert_select ".feed__resolution", text: "The drawer opens, but you cut your hand."
    assert_select ".watch", text: /Ilker is reading the outcome/

    sign_in_as users(:ilker)
    second_scene = stub_understudy(SECOND_SCENE_RESPONSE) do
      perform_enqueued_jobs { post game_session_acknowledgement_path(@room), as: :json }
    end.sole
    assert second_scene["prompt"].end_with?("\n\nScene 2 of 7, Deniz's turn. Raise the stakes: pay for what came before, and let the one who stands in the way act.\n")
    assert_includes second_scene["prompt"], "<user>\nIlker chose \"Force the drawer open\""

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
