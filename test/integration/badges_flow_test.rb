require "test_helper"

class BadgesFlowTest < ActionDispatch::IntegrationTest
  setup do
    @solo, @host = game_sessions(:ilker_solo), players(:ilker_solo_host)
  end

  test "the badges earned sit under the record, and only those" do
    @solo.update! surprise: true
    tell_adventure @solo, title: "The Lighthouse Boy", turns: [ [ @host, "The Inn", "Read the ledger", 4 ], [ @host, "The Stair", "Climb the broken stair", 20 ] ]
    sign_in_as users(:ilker)

    get my_profile_path

    assert_select ".record + .badges"
    assert_select ".badges h2", text: "Badges"
    assert_select ".badge", count: 2
    assert_select ".badge", text: /A 20 at the end\s+Won the finale on a natural 20./
    assert_select ".badge", text: /Surprise\s+Finished a surprise adventure./
  end

  test "a user with a record and no badge sees no badges section" do
    tell_adventure @solo, title: "The Lighthouse Boy", outcome: "defeat", turns: [ [ @host, "The Inn", "Read the ledger", 4 ] ]
    sign_in_as users(:ilker)

    get my_profile_path

    assert_select ".record"
    assert_select ".badges", count: 0
  end

  test "a new player sees neither record nor badges" do
    sign_in_as users(:sevval)

    get my_profile_path

    assert_select ".record, .badges", count: 0
  end

  test "the badges in Turkish" do
    tell_adventure @solo, title: "The Lighthouse Boy", turns: [ [ @host, "The Stair", "Climb the broken stair", 20 ] ]
    sign_in_as users(:ilker)
    patch locale_path, params: { locale: "tr" }

    get my_profile_path

    assert_select ".badges h2", text: "Rozetler"
    assert_select ".badge", text: /Sonda 20\s+Finali zarda 20 gelerek kazandın./
    assert_select ".badge", text: /Her zar tuttu\s+Bir maceranın bütün zarları başarılı oldu./
  end

  test "the badges take as many queries however many games are finished" do
    tell_adventure @solo, title: "The Lighthouse Boy", turns: [ [ @host, "The Stair", "Climb the broken stair", 20 ] ]
    sign_in_as users(:ilker)
    get my_profile_path
    one = count_queries { get my_profile_path }

    3.times do |index|
      game_session = GameSession.create!(creator: users(:ilker), max_players: 5, length: "long", surprise: true)
      guest = game_session.players.create!(user: users(:deniz))
      host = game_session.host
      [ host, guest ].each { ready_warrior it }
      tell_adventure game_session, title: "Another #{index}", ended_at: index.hours.ago, turns: [ host, guest, host ].map { [ it, "Stop", "Press on", 20 ] }
    end

    assert_equal one, count_queries { get my_profile_path }
    assert_select ".badge", count: 5
  end

  test "the finale names a badge earned for the first time, once" do
    tell_adventure @solo, title: "The Lighthouse Boy", turns: [ [ @host, "The Inn", "Read the ledger", 4 ], [ @host, "The Stair", "Climb the broken stair", 20 ] ]
    sign_in_as users(:ilker)

    get game_session_path(@solo)
    assert_select ".finale__new-badges", text: "A new badge: A 20 at the end"
    assert_select ".finale__new-badges a[href=?]", my_profile_path(anchor: "badges")

    get my_adventure_path(@solo)
    assert_select ".finale__outcome", text: "Victory"
    assert_select ".finale__new-badges", count: 0

    again = GameSession.create!(creator: users(:ilker), place: "salt_caves", trouble: "fever", figure: "hermit")
    ready_warrior again.host
    tell_adventure again, title: "Again", turns: [ [ again.host, "The Cave", "Climb", 4 ], [ again.host, "The Pit", "Leap", 20 ] ]

    get game_session_path(again)
    assert_select ".finale__outcome", text: "Victory"
    assert_select ".finale__new-badges", count: 0

    get my_profile_path
    assert_select ".badge", count: 1
  end

  test "the finale names several badges in one line, in the player's own language" do
    @solo.update! surprise: true
    tell_adventure @solo, title: "The Lighthouse Boy", turns: [ [ @host, "The Stair", "Climb the broken stair", 20 ] ]
    sign_in_as users(:ilker)

    get game_session_path(@solo)
    assert_select ".finale__new-badges", text: "New badges: A 20 at the end, Surprise, Every roll"

    patch locale_path, params: { locale: "tr" }
    get game_session_path(@solo)
    assert_select ".finale__new-badges", text: "Yeni rozetler: Sonda 20, Sürpriz, Her zar tuttu"
  end

  test "a party's finale names each player's own badges" do
    room = game_sessions(:ilker_room)
    host, guest = players(:ilker_room_host), players(:deniz_room_guest)
    [ host, guest ].each { ready_warrior it }
    guest.character.update! hp: 1
    tell_adventure room, title: "The Drowned Bell", turns: [ [ guest, "The Quay", "Hail the ferryman", 14 ], [ host, "The Belfry", "Ring the drowned bell", 20 ] ]

    sign_in_as users(:ilker)
    get game_session_path(room)
    assert_select ".finale__new-badges", text: "New badges: A 20 at the end, Every roll"

    sign_in_as users(:deniz)
    get game_session_path(room)
    assert_select ".finale__new-badges", text: "New badges: One health left, Every roll"
  end

  test "an adventure that earns nothing new says nothing" do
    tell_adventure @solo, title: "The Lighthouse Boy", outcome: "defeat", turns: [ [ @host, "The Inn", "Read the ledger", 4 ] ]
    sign_in_as users(:ilker)

    get game_session_path(@solo)

    assert_select ".finale__outcome", text: "Defeat"
    assert_select ".finale__new-badges", count: 0
  end

  private
    def count_queries(&block)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      count
    end
end
