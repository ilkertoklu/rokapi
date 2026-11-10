require "application_system_test_case"

class PlacesTest < ApplicationSystemTestCase
  setup do
    host = players(:ilker_solo_host)
    tell_adventure game_sessions(:ilker_solo), title: "The Lighthouse Boy", ended_at: 2.days.ago, turns: [
      [ host, "The Old Inn", "Read the dusty ledger", 15 ],
      [ host, "The Lighthouse", "Climb the broken stair", 14 ]
    ]

    [ %w[ mining_town fever indebted_smith ], %w[ salt_caves cut_off hermit ] ].each do |place, trouble, figure|
      GameSession.create! creator: users(:ilker), place: place, trouble: trouble, figure: figure,
        started_at: 1.day.ago, ended_at: 1.day.ago + 20.minutes, outcome: "defeat"
    end
  end

  test "three places named among seventeen silhouettes, one opened to what was met there" do
    sign_in_as users(:ilker)

    find(".profile__badge").click
    within(".account") { click_on "Places seen" }
    assert_selector ".page-head h1", text: "Places seen"
    assert_selector ".atlas__tally", text: "3 of 20"
    assert_selector "a.place", count: 3
    assert_selector ".place--unseen", count: 17

    click_on "A fog-bound fishing village"
    assert_selector ".place-story__name", text: "A fog-bound fishing village"
    assert_text "A child went out at dusk and has not come back"
    assert_text "An old weather-reader who pleases no one"

    click_on "The Lighthouse Boy"
    assert_selector ".adventure__scene", count: 2
    assert_text "What came of climb the broken stair."
  end

  test "the finale of a game in a fourth place says it is new" do
    game_sessions(:ilker_solo).update! place: "lighthouse_rock"
    sign_in_as users(:ilker)

    visit game_session_path(game_sessions(:ilker_solo))
    assert_selector ".finale__outcome", text: "VICTORY"
    assert_selector ".finale__new-place", text: "A new place: A lighthouse on a rock out at sea"

    click_on "A lighthouse on a rock out at sea"
    assert_selector ".place-story__name", text: "A lighthouse on a rock out at sea"
  end
end
