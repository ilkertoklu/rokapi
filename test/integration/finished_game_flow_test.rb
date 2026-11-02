require "test_helper"

class FinishedGameFlowTest < ActionDispatch::IntegrationTest
  setup do
    @room = game_sessions(:ilker_room)
    [ players(:ilker_room_host), players(:deniz_room_guest) ].each do |player|
      player.create_character! race: "human", klass: "warrior", background: "soldier",
        stats: Character::Klass.fetch("warrior").base_stats.merge("strength" => 16, "constitution" => 15, "charisma" => 14)
    end
    @room.update! started_at: 1.hour.ago

    climax = @room.scenes.create! position: 1, active_player: players(:ilker_room_host), state: :choosing, title: "The Bridge"
    @choice = climax.choices.create! label: "Cross the bridge", stat: "agility", target: 12
    @room.scenes.create! position: 2, active_player: players(:ilker_room_host), state: :played,
      title: "The Return", narration: "Snow settles over the square.", finale: true
    @room.update! outcome: "defeat"
    @room.finish

    @hero = players(:ilker_room_host).character
    @hero.update! hp: 20
    @potion = @hero.items.create! name: "Healing potion", kind: "instant", hp_effect: 8, uses_left: 1
  end

  test "the player whose turn the finale was cannot move any more" do
    sign_in_as users(:ilker)

    post game_session_item_use_path(@room, @potion), as: :json
    assert_response :conflict
    assert_equal 20, @hero.reload.hp
    assert_equal 1, @potion.reload.uses_left

    post game_session_choice_selection_path(@room, @choice), as: :json
    assert_response :conflict
    assert_nil @choice.reload.chosen_at

    [ game_session_roll_path(@room), game_session_acknowledgement_path(@room), game_session_narration_path(@room) ].each do |path|
      post path, as: :json
      assert_response :conflict, path
    end
    assert_equal 2, @room.scenes.count
  end

  test "everyone else is told the game is over, not that it is not their turn" do
    sign_in_as users(:deniz)

    post game_session_item_use_path(@room, players(:deniz_room_guest).character.items.first), as: :json
    assert_response :conflict
  end

  test "a move on a finished game in the browser returns to the closing screen" do
    sign_in_as users(:ilker)

    post game_session_item_use_path(@room, @potion), headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    assert_redirected_to game_session_path(@room)
    assert_equal 20, @hero.reload.hp
  end
end
