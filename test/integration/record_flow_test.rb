require "test_helper"

class RecordFlowTest < ActionDispatch::IntegrationTest
  setup do
    solo = players(:ilker_solo_host)
    tell_adventure game_sessions(:ilker_solo), title: "The Lighthouse Boy", ended_at: 2.days.ago, turns: [
      [ solo, "The Old Inn", "Read the dusty ledger", 15 ],
      [ solo, "The Lighthouse", "Climb the broken stair", 14 ]
    ]

    [ players(:ilker_room_host), players(:deniz_room_guest) ].each { ready_warrior it }
    tell_adventure game_sessions(:ilker_room), title: "The Drowned Bell", outcome: "defeat", ended_at: 1.day.ago, turns: [
      [ players(:ilker_room_host), "The Quay", "Hail the ferryman", 12 ],
      [ players(:deniz_room_guest), "The Belfry", "Ring the drowned bell", 4 ]
    ]
  end

  test "the record sits under the identity and its adventure count leads to the shelf" do
    sign_in_as users(:ilker)

    get my_profile_path

    assert_select ".identity + .record"
    assert_select ".record h2", text: "Record"
    assert_select ".record__figure", text: /Adventures\s+2/
    assert_select ".record__figure a[href=?]", my_adventures_path, text: "Adventures"
    assert_select ".record__figure", text: /Victory\s+1/
    assert_select ".record__figure", text: /Defeat\s+1/
    assert_select ".record__figure", text: /Dice rolled\s+3/
    assert_select ".record__figure", text: /With a party\s+1/
    assert_select ".record__figure", text: /Played most\s+Warrior/
  end

  test "a party player's record counts only the games they were in" do
    sign_in_as users(:deniz)

    get my_profile_path

    assert_select ".record__figure", text: /Adventure\s+1/
    assert_select ".record__figure", text: /Victories\s+0/
    assert_select ".record__figure", text: /Dice rolled\s+1/
  end

  test "a user with no finished game sees the profile without a record" do
    sign_in_as users(:sevval)

    get my_profile_path

    assert_response :success
    assert_select ".record", count: 0
    assert_select ".identity + a.menu-row[href=?]", subscription_path
  end

  test "the record in Turkish" do
    sign_in_as users(:ilker)
    patch locale_path, params: { locale: "tr" }

    get my_profile_path

    assert_select ".record h2", text: "Kayıt"
    assert_select ".record__figure", text: /Macera\s+2/
    assert_select ".record__figure", text: /Zafer\s+1/
    assert_select ".record__figure", text: /Zar atıldı\s+3/
    assert_select ".record__figure", text: /Favori sınıf\s+Savaşçı/
  end

  test "the profile takes as many queries however many games are finished" do
    sign_in_as users(:sevval)
    get my_profile_path
    empty = count_queries { get my_profile_path }

    sign_in_as users(:ilker)
    get my_profile_path
    two = count_queries { get my_profile_path }

    3.times do |index|
      game_session = GameSession.create!(creator: users(:ilker), max_players: 5)
      game_session.players.create! user: users(:sevval)
      game_session.players.each { ready_warrior it }
      tell_adventure game_session, title: "Another #{index}", ended_at: index.hours.ago, turns: game_session.players.map { [ it, "Stop", "Press on", 9 ] }
    end

    assert_equal two, count_queries { get my_profile_path }
    assert_select ".record__figure", text: /Adventures\s+5/
    assert_equal empty + 5, two
  end

  private
    def count_queries(&block)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      count
    end
end
