require "application_system_test_case"

class RecordTest < ApplicationSystemTestCase
  test "the record on the profile leads to the finished adventures" do
    host = players(:ilker_solo_host)
    tell_adventure game_sessions(:ilker_solo), title: "The Lighthouse Boy", ended_at: 2.days.ago, turns: [
      [ host, "The Old Inn", "Read the dusty ledger", 15 ],
      [ host, "The Lighthouse", "Climb the broken stair", 14 ]
    ]
    sign_in_as users(:ilker)

    find(".profile__badge").click
    within(".record") do
      assert_text "1\nVictory"
      assert_text "2\nDice rolled"
      assert_text "Warrior\nPlayed most"
      click_on "1 Adventure"
    end

    assert_selector ".page-head h1", text: "My adventures"
    assert_link "The Lighthouse Boy"
  end

  test "a new player's profile has no record" do
    sign_in_as users(:sevval)

    find(".profile__badge").click

    assert_selector ".identity__name", text: "Sevval"
    assert_no_selector ".record"
  end
end
