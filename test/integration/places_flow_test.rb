require "test_helper"

class PlacesFlowTest < ActionDispatch::IntegrationTest
  setup do
    @solo = game_sessions(:ilker_solo)
    @host = players(:ilker_solo_host)
    tell_adventure @solo, title: "The Lighthouse Boy", ended_at: 3.days.ago, turns: [
      [ @host, "The Old Inn", "Read the dusty ledger", 15 ],
      [ @host, "The Lighthouse", "Climb the broken stair", 14 ]
    ]

    @mine = finish_at "mining_town", trouble: "fever", figure: "indebted_smith", ended_at: 2.days.ago
    @caves = finish_at "salt_caves", trouble: "cut_off", figure: "hermit", ended_at: 1.day.ago
  end

  test "the places seen are named and the rest are silhouettes" do
    finish_at "border_fort", trouble: "stolen_seal", figure: "young_guard", user: users(:deniz)
    GameSession.create! creator: users(:ilker), place: "city_docks", trouble: "fever", figure: "old_captain"
    sign_in_as users(:ilker)

    get my_places_path

    assert_select ".page-head h1", text: "Places seen"
    assert_select ".atlas__tally", text: "3 of 20"
    assert_select ".place", count: 20
    assert_select "a.place", count: 3
    assert_select ".place--unseen", count: 17
    assert_select "a.place[href=?]", my_place_path("fishing_village"), text: /A fog-bound fishing village\s+1 adventure/
    assert_select "a.place[href=?]", my_place_path("salt_caves"), text: /Salt caves beneath the hills/
    assert_select ".places", text: /A border fort|The docks of a walled city/, count: 0
  end

  test "a seen place opens to what was met there and the adventures played there" do
    @solo.update! surprise: true
    other = finish_at "fishing_village", trouble: "dry_well", figure: "path_child", ended_at: 1.hour.ago
    sign_in_as users(:ilker)

    get my_place_path("fishing_village")

    assert_response :success
    assert_select ".place-story__name", text: "A fog-bound fishing village"
    assert_select ".place-story__troubles li", count: 2
    assert_select ".place-story__troubles", text: /The drinking water has gone foul.*A child went out at dusk/m
    assert_select ".place-story__figures li", count: 2
    assert_select ".place-story__figures", text: /A child who knows every path.*An old weather-reader/m
    assert_select ".shelf__adventure", count: 2
    assert_select ".shelf__adventure[href=?]", my_adventure_path(other)
    assert_select ".shelf__adventure[href=?]", my_adventure_path(@solo), text: /The Lighthouse Boy/
    assert_no_match GameSession::Twist.fetch(@solo.twist).text, response.body
  end

  test "an unseen place does not open" do
    sign_in_as users(:ilker)

    get my_place_path("border_fort")
    assert_response :not_found

    get my_place_path("nowhere")
    assert_response :not_found
  end

  test "a party game counts for every player in it, after one of them departed too" do
    room = game_sessions(:ilker_room)
    [ players(:ilker_room_host), players(:deniz_room_guest) ].each { ready_warrior it }
    room.update! place: "river_ferry"
    tell_adventure room, title: "The Drowned Bell", turns: [ [ players(:deniz_room_guest), "The Quay", "Hail the ferryman", 12 ] ]

    sign_in_as users(:deniz)
    get my_places_path
    assert_select ".atlas__tally", text: "1 of 20"
    assert_select "a.place[href=?]", my_place_path("river_ferry")

    users(:deniz).destroy!
    sign_in_as users(:ilker)
    get my_place_path("river_ferry")
    assert_select ".shelf__title", text: "The Drowned Bell"
  end

  test "a surprise game counts for its place once it is finished" do
    surprise = GameSession.create! creator: users(:ilker), card: "", place: "prison_island", trouble: "fever", figure: "hermit"
    sign_in_as users(:ilker)

    get my_places_path
    assert_select "a.place[href=?]", my_place_path("prison_island"), count: 0

    surprise.update! started_at: 1.hour.ago, ended_at: Time.current, outcome: "victory"
    get my_places_path
    assert_select "a.place[href=?]", my_place_path("prison_island"), text: /A prison island in a cold sea/
  end

  test "the profile leads to the places seen" do
    sign_in_as users(:sevval)

    get my_profile_path
    assert_select "a.menu-row[href=?]", my_places_path, text: /Places seen/

    get my_places_path
    assert_select ".atlas__tally", text: "0 of 20"
    assert_select ".place--unseen", count: 20
  end

  test "the finale names a place seen for the first time, once" do
    @solo.update! place: "lighthouse_rock"
    sign_in_as users(:ilker)

    get game_session_path(@solo)
    assert_select ".finale__new-place", text: "A new place: A lighthouse on a rock out at sea"
    assert_select ".finale__new-place a[href=?]", my_place_path("lighthouse_rock")

    get my_adventure_path(@solo)
    assert_select ".finale__outcome", text: "Victory"
    assert_select ".finale__new-place", count: 0

    @solo.update! place: "salt_caves", ended_at: Time.current
    get game_session_path(@solo)
    assert_select ".finale__outcome", text: "Victory"
    assert_select ".finale__new-place", count: 0
  end

  test "the finale says the place is new in the player's own language" do
    @solo.update! place: "lighthouse_rock"
    sign_in_as users(:ilker)
    patch locale_path, params: { locale: "tr" }

    get game_session_path(@solo)
    assert_select ".finale__new-place", text: "Yeni bir mekân: Açık denizde, bir kayanın üstünde bir fener"
  end

  test "the places take as many queries however many are seen" do
    sign_in_as users(:ilker)
    get my_places_path
    three = count_queries { get my_places_path }

    %w[ river_ferry steppe_camp charcoal_camp ].each { finish_at it, trouble: "fever", figure: "hermit" }

    assert_equal three, count_queries { get my_places_path }
    assert_select "a.place", count: 6
  end

  test "a place takes as many queries however many adventures were played there" do
    sign_in_as users(:ilker)
    get my_place_path("salt_caves")
    one = count_queries { get my_place_path("salt_caves") }

    3.times { finish_at "salt_caves", trouble: "fever", figure: "hermit" }

    assert_equal one, count_queries { get my_place_path("salt_caves") }
    assert_select ".shelf__adventure", count: 4
  end

  private
    def finish_at(place, trouble:, figure:, user: users(:ilker), ended_at: Time.current)
      GameSession.create! creator: user, place: place, trouble: trouble, figure: figure,
        started_at: ended_at - 20.minutes, ended_at: ended_at, outcome: "victory"
    end

    def count_queries(&block)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      count
    end
end
