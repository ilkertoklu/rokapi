require "test_helper"

class ItemUseFlowTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:ilker)

    @game_session = game_sessions(:ilker_solo)
    @game_session.update! started_at: Time.current
    @game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host),
      state: :choosing, title: "The Old Inn", narration: "Rain."
    @character = characters(:ilker_hero)
  end

  test "the sheet offers the potion while it lasts" do
    get game_session_path(@game_session)

    assert_select ".character-button__hint", text: "1 item ready"
    assert_select ".inventory__name", text: "Healing potion"
    assert_select ".inventory__badge", text: "Quest item"
    assert_select ".statuses", count: 0
  end

  test "using the potion heals and swaps the stage for the result" do
    @character.update! hp: 20

    post game_session_item_use_path(@game_session, items(:healing_potion)), as: :turbo_stream

    assert_response :success
    assert_turbo_stream action: "update", target: "game_stage" do
      assert_select "template .outcome__verdict", text: "+7 Health"
      assert_select "template .vitals__count", text: /20\s*→\s*27\s*\/\s*31/
    end
    assert_turbo_stream action: "replace", target: "character_sheet" do
      assert_select "template .inventory__name", text: "Healing potion", count: 0
    end

    get game_session_path(@game_session)
    assert_select ".character-button__hint", count: 0
    assert_select ".inventory__name", text: "Healing potion", count: 0
  end

  test "the result reports the health actually restored" do
    @character.update! hp: 28

    post game_session_item_use_path(@game_session, items(:healing_potion)), as: :turbo_stream

    assert_turbo_stream action: "update", target: "game_stage" do
      assert_select "template .outcome__verdict", text: "+3 Health"
      assert_select "template .vitals__count", text: /28\s*→\s*31\s*\/\s*31/
    end
  end

  test "a spent, passive or foreign item cannot be used" do
    items(:healing_potion).update! uses_left: 0

    post game_session_item_use_path(@game_session, items(:healing_potion))
    assert_response :not_found

    post game_session_item_use_path(@game_session, items(:longsword))
    assert_response :not_found

    post game_session_item_use_path(@game_session, items(:deniz_potion))
    assert_response :not_found
    assert_equal 1, items(:deniz_potion).reload.uses_left, "another player's potion must stay untouched"
  end
end
