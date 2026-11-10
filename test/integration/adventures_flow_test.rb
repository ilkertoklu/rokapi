require "test_helper"

class AdventuresFlowTest < ActionDispatch::IntegrationTest
  setup do
    @solo = game_sessions(:ilker_solo)
    @host = players(:ilker_solo_host)
    tell_adventure @solo, title: "The Lighthouse Boy", ended_at: 2.days.ago, turns: [
      [ @host, "The Old Inn", "Read the dusty ledger", 15 ],
      [ @host, "The Lighthouse", "Climb the broken stair", 3 ]
    ]

    @room = game_sessions(:ilker_room)
    @guest = players(:deniz_room_guest)
    [ players(:ilker_room_host), @guest ].each { ready_warrior it }
    tell_adventure @room, title: "The Drowned Bell", outcome: "defeat", ended_at: 1.day.ago, turns: [
      [ players(:ilker_room_host), "The Quay", "Hail the ferryman", 12 ],
      [ @guest, "The Belfry", "Ring the drowned bell", 20 ]
    ]
  end

  test "the shelf lists finished adventures newest first and leaves ongoing ones off" do
    game_sessions(:deniz_solo).update! title: "Someone else's story"
    sign_in_as users(:ilker)

    get my_adventures_path

    assert_select ".page-head h1", text: "My adventures"
    assert_select ".shelf__title", count: 2
    assert_select ".shelf li:first-child", text: /Defeat\s+The Drowned Bell/
    assert_select ".shelf li:last-child", text: /Victory\s+The Lighthouse Boy\s+.*Human · Warrior · Soldier/
    assert_select "a.shelf__adventure[href=?]", my_adventure_path(@solo)
    assert_select ".shelf", text: /Someone else's story/, count: 0
  end

  test "a solo adventure reads from the first scene to the closing" do
    sign_in_as users(:ilker)

    get my_adventure_path(@solo)

    assert_response :success
    assert_select ".page-head h1", text: "The Lighthouse Boy"
    assert_select ".adventure__scene h2", count: 2
    assert_select ".adventure__scene:first-of-type h2", text: "The Old Inn"
    assert_select ".adventure__scene .narration__body", text: /The Old Inn opens before you/
    assert_select ".adventure__scene .finale__move", text: /Read the dusty ledger\s+BRILLIANT SUCCESS/
    assert_select ".adventure__scene .narration__body", text: /What came of read the dusty ledger/
    assert_select ".adventure__scene .avatar", count: 0

    assert_select ".finale__outcome", text: "Victory"
    assert_select ".finale__move", text: /Climb the broken stair\s+HEAVY FAILURE/
    assert_select ".finale__closing", text: /What came of climb the broken stair/
    assert_select ".highlights", text: /25 min\s+Duration\s+2\s+Dice rolled/

    assert_no_match "Walk away from", response.body
    assert_select "button, form, turbo-cable-stream-source, .sheet", count: 0
  end

  test "a party adventure shows who took each choice, for every player in it" do
    sign_in_as users(:deniz)

    get my_adventures_path
    assert_select ".shelf__title", text: "The Drowned Bell"

    get my_adventure_path(@room)
    assert_select ".adventure__scene .finale__move", text: /Hail the ferryman\s+I\s+Ilker\s+SUCCESS/
    assert_select ".adventure__scene .avatar--seat-0[title=?]", "Ilker"
    assert_select ".finale__outcome", text: "Defeat"
    assert_select ".finale__move", text: /Ring the drowned bell\s+CRITICAL SUCCESS!/
    assert_select ".roster__member", count: 2
  end

  test "a departed player still shows as the one who chose" do
    users(:deniz).destroy!
    sign_in_as users(:ilker)

    get my_adventure_path(@room)

    assert_select ".finale__move .avatar--departed[title=?]", "Departed player"
    assert_select ".roster__member", text: /Departed player/
  end

  test "the closing of an adventure whose finale had no roll is told once" do
    finale = @solo.scenes.find_by!(finale: true)
    finale.chosen_choice.destroy!
    finale.update! narration: "The tide takes the lighthouse at dawn."
    sign_in_as users(:ilker)

    get my_adventure_path(@solo)

    assert_select ".finale__closing", text: /The tide takes the lighthouse/
    assert_equal 1, response.body.scan("The tide takes the lighthouse").size
  end

  test "an ongoing game or someone else's adventure is not on the shelf to read" do
    sign_in_as users(:sevval)

    get my_adventure_path(@solo)
    assert_response :not_found

    sign_in_as users(:ilker)
    @room.update! ended_at: nil

    get my_adventure_path(@room)
    assert_response :not_found
  end

  test "the story stays in the language it was played in while the labels follow the reader" do
    @solo.update! locale: "tr"
    @solo.scenes.find_by!(position: 1).update! narration: "Han kapısı gıcırdıyor."
    sign_in_as users(:ilker)
    patch locale_path, params: { locale: "tr" }

    get my_adventure_path(@solo)

    assert_select ".adventure__scene .narration__body", text: /Han kapısı gıcırdıyor/
    assert_select ".adventure__scene .finale__move", text: /Read the dusty ledger\s+PARLAK BAŞARI/
    assert_select ".finale__outcome", text: "Zafer"
  end

  test "reading an adventure takes as many queries however long it is" do
    sign_in_as users(:ilker)
    get my_adventure_path(@room)
    short = count_queries { get my_adventure_path(@room) }

    finale = @room.scenes.find_by!(finale: true)
    finale.update! finale: false, position: 5
    3.upto(4) do |position|
      scene = @room.scenes.create! position: position, active_player: @guest, state: :played, title: "Stop #{position}", narration: "On."
      scene.choices.create!(label: "Press on", stat: "strength", target: 10, chosen_at: Time.current).create_roll! player: @guest, value: 9, resolution: "Onward."
    end
    finale.update! finale: true

    assert_equal short, count_queries { get my_adventure_path(@room) }
    assert_select ".adventure__scene", count: 4
  end

  test "home links to the shelf only once an adventure is finished" do
    sign_in_as users(:ilker)
    get root_path
    assert_select "a[href=?]", my_adventures_path, text: "My adventures"

    sign_in_as users(:sevval)
    get root_path
    assert_select "a[href=?]", my_adventures_path, count: 0

    get my_profile_path
    assert_select "a.menu-row[href=?]", my_adventures_path, text: /My adventures/

    get my_adventures_path
    assert_select ".shelf", count: 0
    assert_select ".hint", text: /Adventures you finish are kept here/
  end

  test "the shelf and an adventure as JSON" do
    sign_in_as users(:ilker)

    get my_adventures_path, as: :json
    assert_equal [ "The Drowned Bell", "The Lighthouse Boy" ], response.parsed_body.pluck("title")
    assert_equal "Human · Warrior · Soldier", response.parsed_body.last["hero"]

    get my_adventure_path(@room), as: :json
    adventure = response.parsed_body
    assert_equal "defeat", adventure["outcome"]
    assert_equal [ "The Quay", "The Belfry" ], adventure["scenes"].pluck("title")
    assert_equal [ "Ilker", "Deniz" ], adventure["scenes"].map { it.dig("choice", "by") }
    assert_equal "Ring the drowned bell", adventure["scenes"].last.dig("choice", "label")
    assert_equal "critical", adventure["scenes"].last.dig("roll", "grade")
    assert_equal "What came of ring the drowned bell.", adventure["scenes"].last.dig("roll", "resolution")
    assert_equal [ "Ilker", "Deniz" ], adventure["party"].pluck("name")
  end

  private
    def count_queries(&block)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      count
    end
end
