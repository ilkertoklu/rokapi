require "test_helper"

class UsageWallFlowTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:sevval)
  end

  test "the welcome shows the plan the user is on" do
    get signup_welcome_path

    assert_select ".plan__name", text: "Free plan"
    assert_select ".plan__headline", text: "100% left"
    assert_select ".plan li", text: "About 1–2 short adventures a month"
  end

  test "a spent month walls off new adventures" do
    spend_the_month_of users(:sevval)

    get new_game_sessions_solo_path
    assert_select "h1", text: "Your monthly usage is spent"
    assert_select ".usage__left", text: "0% left"
    assert_select "a[href=?]", root_path, text: /Close for now/
    assert_select "form", count: 0

    assert_no_difference -> { GameSession.count } do
      post game_sessions_solo_path, params: { game_session: { quest: "lost_caravan", tone: "balanced", length: "short" } }
    end
    assert_redirected_to new_game_sessions_solo_path
  end

  test "a spent month walls off new rooms too" do
    spend_the_month_of users(:sevval)

    get new_game_sessions_multi_path
    assert_select "h1", text: "Your monthly usage is spent"

    assert_no_difference -> { GameSession.count } do
      post game_sessions_multi_path, params: { game_session: { quest: "lost_caravan", tone: "balanced", length: "short" } }
    end
    assert_redirected_to new_game_sessions_multi_path
  end

  test "the wall answers JSON clients with the refill date" do
    spend_the_month_of users(:sevval)

    assert_no_difference -> { GameSession.count } do
      post game_sessions_solo_path, params: { game_session: { quest: "lost_caravan", tone: "balanced", length: "short" } }, as: :json
    end

    assert_response :payment_required
    assert_match "Your monthly usage is spent", response.parsed_body["error"]
    assert_equal 0, response.parsed_body["usage_left_percentage"]
  end

  test "a guest in someone else's spent game can still start their own" do
    game_session = spend_the_month_of users(:deniz)
    game_session.players.create!(user: users(:sevval))

    get new_game_sessions_solo_path
    assert_select "form[action=?]", game_sessions_solo_path
  end

  private
    def spend_the_month_of(user)
      GameSession.create!(creator: user, quest: "lost_caravan").tap do |game_session|
        user.monthly_plan.scenes.times do |index|
          game_session.scenes.create! position: index + 1, active_player: game_session.host
        end
      end
    end
end
