require "test_helper"

class User::BadgesTest < ActiveSupport::TestCase
  setup do
    @ilker, @deniz = users(:ilker), users(:deniz)
    @solo, @host = game_sessions(:ilker_solo), players(:ilker_solo_host)
    @room = game_sessions(:ilker_room)
  end

  test "a finale won on a natural 20 is earned in the first such game only" do
    tell_adventure @solo, title: "The Lighthouse Boy", ended_at: 2.days.ago, turns: [ [ @host, "The Inn", "Read the ledger", 4 ], [ @host, "The Stair", "Climb", 20 ] ]
    later = finish_solo turns: [ 20 ], ended_at: 1.day.ago

    assert_includes badges_of(@ilker), "natural_twenty_finale"
    assert_includes @ilker.badges.first_earned_in(@solo).map(&:key), "natural_twenty_finale"
    assert_not_includes @ilker.badges.first_earned_in(later).map(&:key), "natural_twenty_finale"
  end

  test "a natural 20 that loses the finale, or rolls before it, is no finale badge" do
    tell_adventure @solo, title: "The Lighthouse Boy", outcome: "defeat", turns: [ [ @host, "The Inn", "Read the ledger", 20 ], [ @host, "The Stair", "Climb", 20 ] ]
    finish_solo turns: [ 20, 9 ]

    assert_not_includes badges_of(@ilker), "natural_twenty_finale"
  end

  test "a finale lost on a natural 1 is earned by the player who rolled it" do
    ready_party
    tell_adventure @room, title: "The Drowned Bell", outcome: "defeat", turns: [ [ players(:ilker_room_host), "The Quay", "Hail", 14 ], [ players(:deniz_room_guest), "The Belfry", "Ring", 1 ] ]

    assert_includes badges_of(@deniz), "natural_one_finale"
    assert_not_includes badges_of(@ilker), "natural_one_finale"
  end

  test "a victory with 1 health left belongs to the hero left with it" do
    ready_party
    players(:deniz_room_guest).character.update! hp: 1
    tell_adventure @room, title: "The Drowned Bell", turns: [ [ players(:ilker_room_host), "The Quay", "Hail", 14 ] ]

    assert_includes badges_of(@deniz), "last_health"
    assert_not_includes badges_of(@ilker), "last_health"
  end

  test "a party of five all standing at the end earns it for all five" do
    party = full_party
    tell_adventure @room, title: "The Drowned Bell", turns: party.map { [ it, "The Quay", "Hail", 14 ] }

    party.each { assert_includes badges_of(it.user), "whole_party" }

    party.last.character.update! hp: 0
    assert_not_includes badges_of(@ilker), "whole_party"
  end

  test "a party victory with a fallen hero earns it for the whole party" do
    ready_party
    players(:deniz_room_guest).character.update! hp: 0
    tell_adventure @room, title: "The Drowned Bell", turns: [ [ players(:ilker_room_host), "The Quay", "Hail", 14 ] ]

    assert_includes badges_of(@ilker), "fallen_hero"
    assert_includes badges_of(@deniz), "fallen_hero"

    @room.update! outcome: "defeat"
    assert_not_includes badges_of(@ilker), "fallen_hero"
  end

  test "a surprise adventure counts once it is finished" do
    @solo.update! surprise: true
    assert_not_includes badges_of(@ilker), "surprise"

    tell_adventure @solo, title: "The Lighthouse Boy", outcome: "defeat", turns: [ [ @host, "The Inn", "Read the ledger", 4 ] ]
    assert_includes badges_of(@ilker), "surprise"
  end

  test "a victory where the user was once defeated" do
    tell_adventure @solo, title: "The Lighthouse Boy", outcome: "defeat", ended_at: 2.days.ago, turns: [ [ @host, "The Inn", "Read the ledger", 4 ] ]
    elsewhere = finish_solo turns: [ 14 ], place: "salt_caves", ended_at: 1.day.ago
    assert_not_includes badges_of(@ilker), "won_back"

    again = finish_solo turns: [ 14 ], place: @solo.place
    assert_equal [ again.id ], [ elsewhere, again ].select { @ilker.badges.first_earned_in(it).map(&:key).include?("won_back") }.map(&:id)
  end

  test "a long adventure won without an item used" do
    long = finish_solo turns: [ 14, 15 ], length: "long"
    assert_includes badges_of(@ilker), "no_items"

    long.players.first.character.items.create! name: "Tonic", kind: "instant", hp_effect: 3, uses_left: 0, used_at: Time.current
    assert_not_includes badges_of(@ilker), "no_items"
  end

  test "a party member's item used counts against the whole party" do
    ready_party
    @room.update! length: "long"
    tell_adventure @room, title: "The Drowned Bell", turns: [ [ players(:ilker_room_host), "The Quay", "Hail", 14 ] ]
    assert_includes badges_of(@ilker), "no_items"

    players(:deniz_room_guest).character.items.create! name: "Tonic", kind: "instant", hp_effect: 3, uses_left: 1, used_at: Time.current
    assert_not_includes badges_of(@ilker), "no_items"
  end

  test "two natural 20s in one adventure by the same player" do
    ready_party
    host, guest = players(:ilker_room_host), players(:deniz_room_guest)
    tell_adventure @room, title: "The Drowned Bell", outcome: "defeat", turns: [ [ host, "The Quay", "Hail", 20 ], [ guest, "The Hall", "Knock", 20 ], [ host, "The Belfry", "Ring", 20 ] ]

    assert_includes badges_of(@ilker), "two_twenties"
    assert_not_includes badges_of(@deniz), "two_twenties"
  end

  test "every roll of an adventure succeeded" do
    tell_adventure @solo, title: "The Lighthouse Boy", turns: [ [ @host, "The Inn", "Read the ledger", 8 ], [ @host, "The Stair", "Climb", 14 ] ]
    assert_includes badges_of(@ilker), "every_roll"

    @solo.rolls.first.update! success: false
    assert_not_includes badges_of(@ilker), "every_roll"
  end

  test "an unfinished game earns nothing and a new player has no badges" do
    @solo.update! surprise: true
    tell_adventure @solo, title: "The Lighthouse Boy", turns: [ [ @host, "The Inn", "Read the ledger", 20 ] ]
    @solo.update! ended_at: nil

    assert_empty badges_of(@ilker)
    assert_empty badges_of(users(:sevval))
  end

  test "badges stay with the players after another one departs" do
    ready_party
    players(:deniz_room_guest).character.update! hp: 0
    tell_adventure @room, title: "The Drowned Bell", turns: [ [ players(:deniz_room_guest), "The Quay", "Hail", 20 ] ]

    @deniz.destroy!

    assert_includes badges_of(@ilker.reload), "fallen_hero"
    assert_includes badges_of(@ilker), "every_roll"
  end

  test "badges are listed in their own order" do
    @solo.update! surprise: true
    tell_adventure @solo, title: "The Lighthouse Boy", turns: [ [ @host, "The Inn", "Read the ledger", 20 ], [ @host, "The Stair", "Climb", 20 ] ]

    assert_equal %w[ natural_twenty_finale surprise two_twenties every_roll ], badges_of(@ilker)
  end

  private
    def badges_of(user)
      user.badges.map(&:key)
    end

    def finish_solo(turns:, ended_at: Time.current, **attributes)
      game_session = GameSession.create!(creator: @ilker, place: "mining_town", trouble: "fever", figure: "hermit", **attributes)
      player = game_session.players.first
      ready_warrior player
      tell_adventure game_session, title: "Another", ended_at: ended_at, turns: turns.map { [ player, "Stop", "Press on", it ] }
      game_session
    end

    def ready_party
      [ players(:ilker_room_host), players(:deniz_room_guest) ].each { ready_warrior it }
    end

    def full_party
      ready_party
      3.times { |index| ready_warrior @room.players.create!(user: User.create!(email: "friend#{index}@example.com")) }
      @room.players.in_join_order.to_a
    end
end
