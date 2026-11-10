require "application_system_test_case"

class AdventuresTest < ApplicationSystemTestCase
  setup do
    host = players(:ilker_solo_host)
    tell_adventure game_sessions(:ilker_solo), title: "The Lighthouse Boy", ended_at: 2.days.ago, turns: [
      [ host, "The Old Inn", "Read the dusty ledger", 15 ],
      [ host, "The Lighthouse", "Climb the broken stair", 14 ]
    ]

    room = game_sessions(:ilker_room)
    [ players(:ilker_room_host), players(:deniz_room_guest) ].each { ready_warrior it }
    tell_adventure room, title: "The Drowned Bell", outcome: "defeat", ended_at: 1.day.ago, turns: [
      [ players(:deniz_room_guest), "The Quay", "Hail the ferryman", 12 ],
      [ players(:ilker_room_host), "The Belfry", "Ring the drowned bell", 4 ]
    ]
  end

  test "reading finished adventures again from the profile" do
    sign_in_as users(:ilker)
    assert_link "My adventures", href: my_adventures_path

    find(".profile__badge").click
    within(".account") { click_on "My adventures" }
    assert_selector ".page-head h1", text: "My adventures"

    click_on "The Lighthouse Boy"
    assert_selector ".adventure__scene", count: 2
    assert_text "The Old Inn opens before you."
    assert_text "What came of read the dusty ledger."
    assert_selector ".finale__outcome", text: "VICTORY"
    assert_text "What came of climb the broken stair."
    assert_no_text "Walk away from"

    click_on "Back"
    click_on "The Drowned Bell"
    assert_selector ".adventure__scene", count: 2
    assert_selector ".adventure__scene .finale__move", text: /Hail the ferryman\s+D\s+Deniz\s+SUCCESS/
    assert_selector ".finale__outcome", text: "DEFEAT"
    assert_text "What came of ring the drowned bell."
    assert_selector ".roster__member", text: "Deniz"
  end

  test "the shelf is a row on the profile, and on home only once an adventure is finished" do
    sign_in_as users(:sevval)
    assert_no_link "My adventures"

    find(".profile__badge").click
    click_on "My adventures"
    assert_text "Adventures you finish are kept here to read again."
  end
end
