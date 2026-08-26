require "test_helper"

class ItemUseFlowTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:ilker)

    @game_session = game_sessions(:ilker_solo)
    @game_session.update! state: :playing
    @game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host),
      state: :choosing, title: "Eski Han", narration: "Yağmur."
    @character = characters(:ilker_hero)
  end

  test "the sheet offers the potion while it lasts" do
    get game_session_path(@game_session)

    assert_select ".character-button__hint", text: "1 eşya hazır"
    assert_select ".inventory__name", text: "Şifa iksiri"
    assert_select ".inventory__badge", text: "Görev eşyası"
    assert_select ".statuses", count: 0
  end

  test "using the potion heals and swaps the stage for the result" do
    @character.update! hp: 20

    post game_session_item_use_path(@game_session, items(:sifa_iksiri)), as: :turbo_stream

    assert_response :success
    assert_turbo_stream action: "update", target: "game_stage" do
      assert_select "template .outcome__verdict", text: "+7 Can"
      assert_select "template .vitals__count", text: /20\s*→\s*27\s*\/\s*31/
    end
    assert_turbo_stream action: "replace", target: "character_sheet" do
      assert_select "template .inventory__name", text: "Şifa iksiri", count: 0
    end

    get game_session_path(@game_session)
    assert_select ".character-button__hint", count: 0
    assert_select ".inventory__name", text: "Şifa iksiri", count: 0
  end

  test "the result reports the health actually restored" do
    @character.update! hp: 28

    post game_session_item_use_path(@game_session, items(:sifa_iksiri)), as: :turbo_stream

    assert_turbo_stream action: "update", target: "game_stage" do
      assert_select "template .outcome__verdict", text: "+3 Can"
      assert_select "template .vitals__count", text: /28\s*→\s*31\s*\/\s*31/
    end
  end

  test "a spent, passive or foreign item cannot be used" do
    items(:sifa_iksiri).update! uses_left: 0

    post game_session_item_use_path(@game_session, items(:sifa_iksiri))
    assert_response :not_found

    post game_session_item_use_path(@game_session, items(:uzun_kilic))
    assert_response :not_found

    post game_session_item_use_path(@game_session, items(:deniz_iksiri))
    assert_response :not_found
    assert_equal 1, items(:deniz_iksiri).reload.uses_left, "another player's potion must stay untouched"
  end
end
