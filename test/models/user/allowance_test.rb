require "test_helper"

class User::AllowanceTest < ActiveSupport::TestCase
  test "every user starts on the free plan with the whole month left" do
    user = User.create!(email: "yeni@example.com")

    assert_equal Plan.fetch("free"), user.monthly_plan
    assert_equal 100, user.usage_left_percentage
    assert_not user.out_of_usage?
  end

  test "plans come from the catalog" do
    assert_not User.new(email: "gold@example.com", plan: "gold").valid?
  end

  test "each scene played spends the allowance until the wall" do
    user = users(:sevval)
    game_session = GameSession.create!(creator: user, quest: "lost_caravan")

    play_scenes game_session, 9
    assert_equal 10, user.usage_left_percentage
    assert_not user.out_of_usage?

    play_scenes game_session, 1
    assert_equal 0, user.usage_left_percentage
    assert user.out_of_usage?

    play_scenes game_session, 3
    assert_equal 0, user.usage_left_percentage, "a game that runs past the wall plays on"
  end

  test "only sessions the user created spend, joining never does" do
    host, guest = users(:deniz), users(:sevval)
    game_session = GameSession.create!(creator: host, quest: "lost_caravan")
    game_session.players.create!(user: guest)

    play_scenes game_session, 10

    assert host.out_of_usage?
    assert_equal 100, guest.usage_left_percentage
  end

  test "a bigger plan stretches the same play" do
    user = users(:sevval)
    user.update! plan: "standard"

    play_scenes GameSession.create!(creator: user, quest: "lost_caravan"), 10

    assert_equal 84, user.usage_left_percentage
  end

  test "usage refills on the monthly anniversary of signing up" do
    user = travel_to(Time.zone.local(2026, 1, 31, 12)) { User.create!(email: "aysonu@example.com") }

    travel_to Time.zone.local(2026, 3, 10) do
      play_scenes GameSession.create!(creator: user, quest: "lost_caravan"), 10

      assert user.out_of_usage?
      assert_equal Time.zone.local(2026, 3, 31, 12), user.usage_refills_at
    end

    travel_to(Time.zone.local(2026, 3, 31, 11, 59)) { assert user.out_of_usage? }
    travel_to(Time.zone.local(2026, 3, 31, 12)) { assert_equal 100, user.usage_left_percentage }
  end

  test "scenes from before the current month no longer count" do
    user = travel_to(Time.zone.local(2026, 1, 10)) { User.create!(email: "eski@example.com") }
    game_session = travel_to(Time.zone.local(2026, 2, 1)) { GameSession.create!(creator: user, quest: "lost_caravan") }

    travel_to(Time.zone.local(2026, 2, 9)) { play_scenes game_session, 8 }
    travel_to(Time.zone.local(2026, 2, 10)) { play_scenes game_session, 1 }

    travel_to Time.zone.local(2026, 2, 20) do
      assert_equal 90, user.usage_left_percentage
    end
  end

  private
    def play_scenes(game_session, count)
      count.times do
        game_session.scenes.create! position: game_session.scenes.maximum(:position).to_i + 1, active_player: game_session.host
      end
    end
end
