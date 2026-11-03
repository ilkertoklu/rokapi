require "test_helper"

class RematchFlowTest < ActionDispatch::IntegrationTest
  setup do
    @room = game_sessions(:ilker_room)
    @room.players.create!(user: users(:sevval))
    @room.players.each { |player| player.ready_up(warrior) }
    @room.update! started_at: 1.hour.ago, ended_at: Time.current
    @room.scenes.create! position: 1, active_player: players(:ilker_room_host), state: :played, finale: true,
      title: "The Return", narration: "The caravan bells echo."
    @room.update! outcome: "victory"
  end

  test "the closing screen shows who is still standing" do
    players(:deniz_room_guest).character.update! hp: 0
    sign_in_as users(:ilker)

    get game_session_path(@room)

    assert_select ".highlights div", text: /2\s*Alive/
    assert_select ".roster__member", 3
    assert_select ".roster__member--fallen", text: /Deniz/
    assert_select "form[action=?] button", game_session_rematch_path(@room), text: "New adventure"
    assert_select "[data-share-text-value*=?]", "Party: Ilker, Deniz, Sevval"
  end

  test "new adventure takes the whole party into one fresh lobby" do
    sign_in_as users(:sevval)
    post game_session_rematch_path(@room)

    rematch = @room.reload.rematch
    assert_redirected_to game_session_path(rematch)
    assert_not rematch.started?
    assert_equal [ users(:sevval), users(:ilker), users(:deniz) ], rematch.party.map(&:user)

    follow_redirect!
    assert_select ".lobby-player", 3

    sign_in_as users(:deniz)
    assert_no_difference -> { GameSession.count } do
      post game_session_rematch_path(@room), as: :json
    end
    assert_response :created
    assert_equal game_session_url(rematch), response.location
  end

  test "opening the rematch spends usage, joining it does not" do
    spend_the_month_of users(:ilker)
    sign_in_as users(:ilker)

    assert_no_difference -> { GameSession.count } do
      post game_session_rematch_path(@room), as: :json
    end
    assert_response :payment_required

    @room.start_rematch(by: users(:deniz))

    post game_session_rematch_path(@room), as: :json
    assert_response :created
  end

  test "solo games and unfinished rooms have no rematch" do
    sign_in_as users(:ilker)

    post game_session_rematch_path(game_sessions(:ilker_solo)), as: :json
    assert_response :conflict

    @room.update! ended_at: nil
    post game_session_rematch_path(@room), as: :json
    assert_response :conflict
  end

  test "asking an unfinished room for a rematch goes back to the game" do
    @room.update! ended_at: nil
    sign_in_as users(:ilker)

    assert_no_difference -> { GameSession.count } do
      post game_session_rematch_path(@room)
    end
    assert_redirected_to game_session_path(@room)
  end

  private
    def warrior
      { race: "human", klass: "warrior", background: "soldier",
        stats: Character::Klass.fetch("warrior").base_stats.merge("strength" => 16, "constitution" => 15, "charisma" => 14) }
    end

    def spend_the_month_of(user)
      game_session = GameSession.create!(creator: user)
      user.monthly_plan.scenes.times do |index|
        game_session.scenes.create! position: index + 1, active_player: game_session.host
      end
    end
end
