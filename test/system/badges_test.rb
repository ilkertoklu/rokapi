require "application_system_test_case"

class BadgesTest < ApplicationSystemTestCase
  setup do
    host = players(:ilker_solo_host)
    tell_adventure game_sessions(:ilker_solo), title: "The Lighthouse Boy", ended_at: 2.days.ago, turns: [
      [ host, "The Old Inn", "Read the dusty ledger", 4 ],
      [ host, "The Lighthouse", "Climb the broken stair", 20 ]
    ]
  end

  test "the profile shows the badges earned under the record" do
    sign_in_as users(:ilker)

    find(".profile__badge").click

    assert_selector ".record + .badges"
    within(".badges") do
      assert_selector ".badge", count: 1
      assert_text "A 20 at the end"
      assert_text "Won the finale on a natural 20."
    end
  end
end
