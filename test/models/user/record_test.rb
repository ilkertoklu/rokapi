require "test_helper"

class User::RecordTest < ActiveSupport::TestCase
  setup do
    @ilker, @deniz = users(:ilker), users(:deniz)

    solo = players(:ilker_solo_host)
    tell_adventure game_sessions(:ilker_solo), title: "The Lighthouse Boy", ended_at: 3.days.ago, turns: [
      [ solo, "The Old Inn", "Read the dusty ledger", 15 ],
      [ solo, "The Lighthouse", "Climb the broken stair", 14 ]
    ]

    well = players(:ilker_without_character_host)
    ready_hero well, "warrior"
    tell_adventure game_sessions(:ilker_without_character), title: "The Dry Well", outcome: "defeat", ended_at: 2.days.ago, turns: [
      [ well, "The Well", "Climb down the rope", 2 ]
    ]

    host, guest = players(:ilker_room_host), players(:deniz_room_guest)
    ready_hero host, "mage"
    ready_hero(guest, "rogue").update! hp: 0
    tell_adventure game_sessions(:ilker_room), title: "The Drowned Bell", ended_at: 1.day.ago, turns: [
      [ host, "The Quay", "Hail the ferryman", 12 ],
      [ guest, "The Belfry", "Ring the drowned bell", 20 ]
    ]

    deniz_solo = players(:deniz_solo_host)
    tell_adventure game_sessions(:deniz_solo), title: "Unfinished", ended_at: 1.hour.ago, turns: [
      [ deniz_solo, "The Gate", "Knock twice", 11 ],
      [ deniz_solo, "The Hall", "Light the hearth", 9 ]
    ]
    game_sessions(:deniz_solo).update! ended_at: nil, outcome: nil
  end

  test "the record counts the finished solo and party games the user played in" do
    record = @ilker.record

    assert record.any?
    assert_equal 3, record.adventures
    assert_equal 2, record.victories
    assert_equal 1, record.defeats
    assert_equal 4, record.dice_rolled
    assert_equal 1, record.party_adventures
    assert_equal Character::Klass.fetch("warrior"), record.favorite_klass
  end

  test "a party's victory counts for a hero who fell on the way, and an unfinished game adds nothing" do
    record = @deniz.record

    assert_equal 1, record.adventures
    assert_equal 1, record.victories
    assert_equal 0, record.defeats
    assert_equal 1, record.dice_rolled
    assert_equal 1, record.party_adventures
    assert_equal Character::Klass.fetch("rogue"), record.favorite_klass
  end

  test "a party game still counts once another player in it has departed" do
    @deniz.destroy!

    assert_equal 3, @ilker.reload.record.adventures
    assert_equal 1, @ilker.record.party_adventures
    assert_equal 4, @ilker.record.dice_rolled
  end

  test "the class played most is the latest one when two are played as often" do
    players(:ilker_without_character_host).character.destroy!
    players(:ilker_room_host).character.update! created_at: 1.week.ago

    assert_equal Character::Klass.fetch("warrior"), @ilker.record.favorite_klass

    players(:ilker_room_host).character.update! created_at: 1.minute.from_now

    assert_equal Character::Klass.fetch("mage"), @ilker.record.favorite_klass
  end

  test "a user with no finished game has no record" do
    record = users(:sevval).record

    assert_not record.any?
    assert_equal 0, record.adventures
    assert_nil record.favorite_klass
  end

  private
    def ready_hero(player, klass)
      stats = Character::Klass.fetch(klass).base_stats
      player.create_character! race: "human", klass: klass, background: "soldier", stats: stats.merge("constitution" => stats["constitution"] + 3, "wisdom" => stats["wisdom"] + 3)
    end
end
