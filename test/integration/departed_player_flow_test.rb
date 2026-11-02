require "test_helper"

class DepartedPlayerFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @room = game_sessions(:ilker_room)
  end

  test "a guest who played a turn leaves the story as a departed player" do
    sevval = @room.join(users(:sevval))
    @room.players.each { it.ready_up(warrior) }
    @room.start(by: players(:ilker_room_host))
    @room.advance
    deniz = players(:deniz_room_guest)
    play_turn_of deniz

    sign_in_as users(:deniz)
    delete my_account_path, params: { confirmation: "DELETE" }
    assert_redirected_to welcome_path

    assert_not User.exists?(users(:deniz).id)
    assert GameSession.exists?(@room.id)
    assert deniz.reload.departed?
    assert deniz.character.present?
    assert_equal deniz, @room.rolls.sole.player

    @room.advance
    @room.advance
    @room.advance
    assert_equal [ players(:ilker_room_host), deniz, sevval, players(:ilker_room_host), sevval ],
      @room.scenes.chronological.map(&:active_player)

    @room.current_scene.update! state: :choosing, title: "The Stable"
    sign_in_as users(:ilker)
    get game_session_path(@room)
    assert_select ".party__others .avatar--departed[title=?]", "Departed player"

    get game_session_path(@room), as: :json
    assert_equal [ "Ilker", "Departed player", "Sevval" ], response.parsed_body["players"].pluck("name")
  end

  test "a guest who leaves an unstarted room is taken off it" do
    sign_in_as users(:deniz)
    delete my_account_path, params: { confirmation: "DELETE" }

    assert_equal [ players(:ilker_room_host) ], @room.players.reload
  end

  test "a rematch leaves departed players behind" do
    @room.players.each { it.ready_up(warrior) }
    @room.start(by: players(:ilker_room_host))
    @room.finish
    players(:deniz_room_guest).depart

    rematch = @room.start_rematch(by: players(:ilker_room_host).user)

    assert_equal [ users(:ilker) ], rematch.players.map(&:user)
  end

  private
    def play_turn_of(player)
      scene = @room.current_scene
      assert_equal player, scene.active_player

      scene.update! state: :choosing, title: "The Old Inn"
      choice = scene.choices.create! label: "Force the drawer open", stat: "strength", modifier: 3, target: 12
      choice.choose
      scene.roll_dice by: player
    end

    def warrior
      { race: "human", klass: "warrior", background: "soldier",
        stats: Character::Klass.fetch("warrior").base_stats.merge("strength" => 16, "constitution" => 15, "charisma" => 14) }
    end
end
