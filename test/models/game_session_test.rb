require "test_helper"
require "turbo/broadcastable/test_helper"

class GameSessionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper, Turbo::Broadcastable::TestHelper

  test "creating a session enrolls the creator" do
    game_session = GameSession.create!(creator: users(:ilker), card: "mining_town dry_well indebted_smith")

    assert_equal users(:ilker), game_session.players.sole.user
    assert_equal game_session.players.sole, game_session.host
    assert_not game_session.started?
  end

  test "a new session keeps the language it was started in" do
    game_session = I18n.with_locale(:tr) { GameSession.create!(creator: users(:ilker), card: "mining_town dry_well indebted_smith") }

    assert_equal "tr", game_session.locale
    assert_not GameSession.new(creator: users(:ilker), locale: "xx").valid?
  end

  test "title falls back on the place, or on surprise when the card is face down" do
    assert_equal "A fog-bound fishing village", game_sessions(:ilker_solo).title
    assert_equal "Surprise adventure", GameSession.new(surprise: true).title
  end

  test "tone and length are named in the page language" do
    game_session = GameSession.new(tone: "dark", length: "long")

    assert_equal [ "Dark", "Long", "~60 min" ], [ game_session.tone_label, game_session.length_label, game_session.length_estimate ]
  end

  test "a picked card is played as it was shown, with a twist drawn on the server" do
    game_session = GameSession.create!(creator: users(:ilker), card: "salt_caves lost_messenger old_captain")

    assert_equal %w[ salt_caves lost_messenger old_captain ], game_session.card.keys
    assert_not game_session.surprise?
    assert_includes game_session.card.trouble.twists, game_session.twist
  end

  test "every trouble turns on twists that exist, and every twist fits some trouble" do
    twists = GameSession::Trouble.all.flat_map(&:twists)

    assert_empty twists - GameSession::Twist.keys
    assert_empty GameSession::Twist.keys - twists
  end

  test "a surprise draws a card the player does not see" do
    game_session = GameSession.create!(creator: users(:ilker), card: "")

    assert game_session.surprise?
    assert_kind_of GameSession::Card, game_session.card
  end

  test "a card made of unknown keys is refused" do
    assert_not GameSession.new(creator: users(:ilker), card: "nowhere dry_well indebted_smith").valid?
    assert_not GameSession.new(creator: users(:ilker), card: "mining_town dry_well").valid?
  end

  test "a hand never repeats a place or a trouble, and leaves out the creator's latest ones" do
    latest = GameSession::Place.all.first(5).zip(GameSession::Trouble.all.first(5)).map do |place, trouble|
      GameSession.create!(creator: users(:sevval), card: "#{place.key} #{trouble.key} young_guard")
    end

    20.times do
      hand = GameSession::Card.deal(to: users(:sevval))

      assert_equal 3, hand.map(&:place).uniq.size
      assert_equal 3, hand.map(&:trouble).uniq.size
      assert_empty hand.map { it.place.key } & latest.map(&:place)
      assert_empty hand.map { it.trouble.key } & latest.map(&:trouble)
    end
  end

  test "a card draws its trouble and figure from the ones its place holds" do
    20.times do
      GameSession::Card.deal(to: users(:sevval)).each do |card|
        assert_includes card.place.troubles, card.trouble.key
        assert_includes card.place.figures, card.figure.key
      end
    end
  end

  test "every place holds known troubles and figures, and every trouble and figure has a place" do
    troubles, figures = GameSession::Place.all.flat_map(&:troubles), GameSession::Place.all.flat_map(&:figures)

    assert_empty troubles - GameSession::Trouble.keys
    assert_empty figures - GameSession::Figure.keys
    assert_empty GameSession::Trouble.keys - troubles
    assert_empty GameSession::Figure.keys - figures
    assert GameSession::Place.all.all? { it.troubles.size >= GameSession::LATEST + GameSession::Card::HAND }
  end

  test "names are drawn in the story's language, leaving out the creator's latest plans and the party" do
    users(:sevval).update!(name: "Ayşe")
    GameSession.create!(creator: users(:sevval), card: "salt_caves lost_messenger old_captain", plan: "Hatice, Hasan'ın mektubunu sakladı.")
    game_session = GameSession.create!(creator: users(:sevval), card: "salt_caves lost_messenger old_captain", locale: "tr")

    20.times do
      names = game_session.fresh_names

      assert_equal GameSession::NAMES, names.uniq.size
      assert_empty names - I18n.t("game_session.names", locale: :tr)
      assert_empty names & %w[ Hatice Hasan Ayşe ]
    end
  end

  test "the latest pasts are what the creator's latest plans hid, newest first" do
    GameSession.create!(creator: users(:sevval), card: "lighthouse_rock called_debt hiding_apprentice",
      plan: "**Question:** Will the debt be paid?\n\n**Opening:** A storm.\n\n**Hidden:** The smith fouled the well.\nNobody knows.\n\n**People:**\n- Edda")
    [ "Mara hid her son.", "The keeper slept and the light went out." ].each do |hidden|
      GameSession.create!(creator: users(:sevval), card: "lighthouse_rock called_debt hiding_apprentice",
        plan: "**Question:** Will the debt be paid?\n\n**Opening:** A storm.\n\n**Believed:** The sea took the light.\n\n**Hidden:** #{hidden}\nNobody knows.\n\n**People:**\n- Edda\n\n**Clues:**\n1. A cold lamp.")
    end
    GameSession.create!(creator: users(:ilker), card: "lighthouse_rock called_debt hiding_apprentice", plan: "**Question:** ?\n\n**Opening:** .\n\n**Hidden:** Someone else's.")
    game_session = GameSession.create!(creator: users(:sevval), card: "lighthouse_rock called_debt hiding_apprentice")

    assert_equal [ "The keeper slept and the light went out. Nobody knows.", "Mara hid her son. Nobody knows.", "The smith fouled the well. Nobody knows." ], game_session.latest_pasts
    assert_empty GameSession.new.latest_pasts
  end

  test "every language holds a hundred different names" do
    I18n.available_locales.each do |locale|
      names = I18n.t("game_session.names", locale: locale)

      assert_operator names.size, :>=, 100
      assert_equal names.uniq, names
    end
  end

  test "starts and calls the narrator once every player has a character" do
    game_session = game_sessions(:ilker_without_character)

    assert_no_enqueued_jobs only: Scene::NarrateJob do
      game_session.start_when_ready
    end
    assert_not game_session.started?
    assert_empty game_session.scenes

    players(:ilker_without_character_host).create_character! race: "human", klass: "warrior", background: "soldier",
      stats: Character::Klass.fetch("warrior").base_stats.merge("strength" => 16, "constitution" => 15, "charisma" => 14)

    assert_enqueued_with job: Scene::NarrateJob do
      game_session.start_when_ready
    end
    assert game_session.reload.started?
    assert game_session.scenes.sole.narrating?
  end

  test "destroying a session cascades through every play record" do
    game_session = game_sessions(:ilker_solo)
    game_session.update! plan: nil
    stub_understudy(*PLANNING) { game_session.plan_story }
    scene = game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host),
      state: :choosing, title: "The Old Inn"
    choice = scene.choices.create! label: "Read the ledger", stat: "intelligence",
      modifier: -1, target: 10
    choice.choose
    scene.roll_dice(by: players(:ilker_solo_host))
    stub_understudy(OUTCOME_RESPONSE) { game_session.rolls.sole.narrate }

    game_session.destroy

    assert_empty Scene.where(game_session_id: game_session.id)
    assert_empty Roll.where(choice_id: choice.id)
    assert_empty Player.where(game_session_id: game_session.id)
    assert_empty Narrator::Conversation.where(game_session_id: game_session.id)
    assert_empty Narrator::Message.all
    assert_empty RubyLLM::ActiveRecord::Usage.all
  end

  test "ongoing scope" do
    assert_includes GameSession.ongoing, game_sessions(:ilker_solo)

    game_sessions(:ilker_solo).finish
    assert_not_includes GameSession.ongoing, game_sessions(:ilker_solo)
  end

  test "a room gets a four digit code and solo gets none" do
    room = GameSession.create!(creator: users(:ilker), card: "mining_town dry_well indebted_smith", max_players: GameSession::PARTY_SIZE)

    assert_match(/\A\d{4}\z/, room.code)
    assert room.multiplayer?
    assert_not game_sessions(:ilker_solo).multiplayer?
    assert_not GameSession.new(creator: users(:ilker), max_players: 3).valid?
  end

  test "a room code stays unique until its room starts" do
    taken = game_sessions(:ilker_room).code
    room = create_room

    assert_not_equal taken, room.code
    assert_raises(ActiveRecord::RecordNotUnique) { room.update! code: taken }

    game_sessions(:ilker_room).update! started_at: Time.current
    assert room.update!(code: taken)
  end

  test "open for join finds a room by code" do
    assert_equal game_sessions(:ilker_room), GameSession.open_for_join("4821")
  end

  test "open for join refuses unknown codes, solo sessions, started and stale rooms" do
    assert_raises(GameSession::NotFound) { GameSession.open_for_join("0000") }
    assert_raises(GameSession::NotFound) { GameSession.open_for_join(nil) }

    game_sessions(:ilker_room).update! created_at: 25.hours.ago
    assert_raises(GameSession::NotFound) { GameSession.open_for_join("4821") }

    game_sessions(:ilker_room).update! created_at: Time.current, started_at: Time.current
    assert_raises(GameSession::NotFound) { GameSession.open_for_join("4821") }
  end

  test "joining a room adds the player once and refreshes the lobby" do
    room = game_sessions(:ilker_room)

    player = nil
    assert_turbo_stream_broadcasts(room) { player = room.join(users(:sevval)) }

    assert_equal users(:sevval), player.user
    assert_equal player, room.join(users(:sevval))
    assert_equal 3, room.players.count
  end

  test "joining a full room is refused" do
    room = game_sessions(:ilker_room)
    room.join(users(:sevval))
    2.times { |index| room.join(User.create!(email: "guest#{index}@example.com")) }

    assert room.full?
    assert_raises(GameSession::Full) { room.join(User.create!(email: "late@example.com")) }
  end

  test "joining after the start is refused" do
    room = game_sessions(:ilker_room)
    room.update! started_at: Time.current

    assert_raises(GameSession::NotFound) { room.join(users(:sevval)) }
    assert_equal players(:deniz_room_guest), room.join(users(:deniz))
  end

  test "a room waits for its host even when everyone is ready" do
    room = game_sessions(:ilker_room)

    assert_no_enqueued_jobs only: Scene::NarrateJob do
      players(:ilker_room_host).ready_up(character_attributes)
      assert_turbo_stream_broadcasts(room) { players(:deniz_room_guest).ready_up(character_attributes) }
    end
    assert players(:deniz_room_guest).ready?
    assert room.everyone_ready?
    assert_not room.reload.started?
  end

  test "a room starts only once everyone is ready" do
    room = game_sessions(:ilker_room)
    players(:ilker_room_host).ready_up(character_attributes)

    assert_not room.everyone_ready?
    assert_raises(GameSession::NotReady) { room.start }
    assert_not room.reload.started?

    players(:deniz_room_guest).ready_up(character_attributes)

    assert_enqueued_with job: Scene::NarrateJob do
      room.start
    end
    assert room.reload.started?
    assert_equal players(:ilker_room_host), room.scenes.sole.active_player
  end

  test "turns rotate through the party in join order, up to the last scene" do
    room = game_sessions(:ilker_room)
    sevval = room.join(users(:sevval))
    room.players.each { it.ready_up(character_attributes) }

    room.start
    (room.scene_budget - 1).times { room.advance }

    host, deniz = players(:ilker_room_host), players(:deniz_room_guest)
    assert_equal [ host, deniz, sevval, host, deniz, sevval, host ], room.scenes.chronological.map(&:active_player)
  end

  test "turns pass over a fallen hero" do
    room = game_sessions(:ilker_room)
    sevval = room.join(users(:sevval))
    room.players.each { it.ready_up(character_attributes) }

    room.start
    room.advance
    players(:deniz_room_guest).character.update! hp: 0
    3.times { room.advance }

    host, deniz = players(:ilker_room_host), players(:deniz_room_guest)
    assert_equal [ host, deniz, sevval, host, sevval ], room.scenes.chronological.map(&:active_player)
  end

  test "the clues found are the ones the successes won, in the plan's order" do
    game_session = game_sessions(:ilker_solo)
    game_session.update! plan: "Clues:\n1. Mara's shawl hangs on the lighthouse door.\n2. The boy's boots stand dry.\n3. The press gang's list carries his name."

    [ 15, 2, 15 ].each.with_index(1) do |die, position|
      roll_in(game_session, position: position, value: die).resolve resolution: "You press on.", effects: {}
    end

    assert_equal [ 1, 2 ], game_session.reload.clues_found
  end

  test "the clues found leave out what is not a clue's number, and count each once" do
    game_session = game_sessions(:ilker_solo)

    [ 3, nil, "1", "the boot", 0, 3 ].each.with_index(1) do |clue, position|
      roll_in(game_session, position: position).update! effects: { "clue" => clue }.compact
    end

    assert_equal [ 1, 3 ], game_session.reload.clues_found
  end

  test "the next clue is the first of the plan's numbered ones not found yet" do
    game_session = game_sessions(:ilker_solo)
    game_session.update! plan: "Hidden: Mara hid her son.\n\nClues:\n1. Mara's shawl hangs on the lighthouse door.\n2) The boy's boots stand dry.\n- 3. The press gang's list carries his name."

    assert_equal 1, game_session.next_clue
    assert_equal 3, game_session.clues_left

    roll_in(game_session, position: 1).resolve resolution: "You press on.", effects: {}
    game_session.reload

    assert_equal 2, game_session.next_clue
    assert_equal 2, game_session.clues_left

    roll_in(game_session, position: 2, value: 2).resolve resolution: "You slip.", effects: {}
    game_session.reload

    assert_equal 2, game_session.next_clue
    assert_equal 2, game_session.clues_left

    roll_in(game_session, position: 3).resolve resolution: "You press on.", effects: {}
    roll_in(game_session, position: 4).resolve resolution: "You press on.", effects: {}
    game_session.reload

    assert_nil game_session.next_clue
    assert_equal 0, game_session.clues_left
  end

  test "a plan without numbered clues has no next clue and none left" do
    game_session = game_sessions(:ilker_solo)

    assert_nil game_session.next_clue
    assert_equal 0, game_session.clues_left

    roll_in(game_session, position: 1).resolve resolution: "You press on.", effects: {}
    game_session.reload

    assert_nil game_session.next_clue
    assert_equal 0, game_session.clues_left

    game_session.update! plan: nil

    assert_nil game_session.next_clue
    assert_equal 0, game_session.clues_left
  end

  test "a clue is overdue once the scenes left are no more than the clues left, and the scene that shows it counts it as found" do
    game_session = game_sessions(:ilker_solo)
    game_session.update! plan: "Clues:\n1. Mara's shawl hangs on the lighthouse door.\n2. The boy's boots stand dry.\n3. The press gang's list carries his name."
    scenes = (1..game_session.scene_budget).index_with { game_session.scenes.create!(position: it, active_player: game_session.host) }

    assert_equal [ 4, 5, 6 ], scenes.select { |_, scene| scene.clue_overdue? }.keys

    scenes[3].write narration: "The tide is still out.", effects: {}
    scenes[4].write narration: "The press gang rows in.", effects: {}

    assert_not scenes[3].effects.key?("clue")
    assert_equal 1, scenes[4].effects["clue"]
    assert_equal [ 1 ], game_session.reload.clues_found
    assert_equal 2, game_session.next_clue
    assert_equal 2, game_session.clues_left
  end

  test "each clue comes into reach no sooner than its share of the story" do
    game_session = game_sessions(:ilker_solo)
    game_session.update! plan: "Clues:\n1. Mara's shawl hangs on the lighthouse door.\n2. The press gang's list carries his name."
    first = roll_in(game_session, position: 1)

    assert_equal 1, first.scene.clue_in_reach

    first.resolve resolution: "The shawl is wet.", effects: {}
    scenes = (2..game_session.scene_budget).index_with { game_session.scenes.create!(position: it, active_player: game_session.host) }

    assert_equal [ 1 ], game_session.reload.clues_found
    assert_equal({ 2 => nil, 3 => nil, 4 => 2, 5 => 2, 6 => nil, 7 => nil }, scenes.transform_values(&:clue_in_reach))
  end

  test "the marks are what the rolls changed for good, in the order they were rolled" do
    game_session = game_sessions(:ilker_solo)

    [ "The keeper trusts Ilker.", nil, "", "The boat is gone." ].each.with_index(1) do |mark, position|
      roll_in(game_session, position: position).resolve resolution: "You press on.", effects: { "mark" => mark }.compact
    end

    assert_equal [ "The keeper trusts Ilker.", "The boat is gone." ], game_session.reload.marks
  end

  test "solo play stays with the host every scene" do
    game_session = game_sessions(:ilker_without_character)
    players(:ilker_without_character_host).ready_up(character_attributes)
    3.times { game_session.advance }

    assert game_session.reload.started?
    assert_equal [ players(:ilker_without_character_host) ], game_session.scenes.map(&:active_player).uniq
  end

  test "only a finished party game can be played again" do
    assert_not game_sessions(:ilker_room).rematchable?
    assert_not game_sessions(:ilker_solo).tap(&:finish).rematchable?
    assert finished_room.rematchable?
  end

  test "a rematch opens a fresh lobby with the same party and settings" do
    room = finished_room
    sevval = room.players.create!(user: users(:sevval))

    rematch = room.start_rematch(by: users(:deniz))

    assert_not rematch.started?
    assert rematch.lobby?
    assert_not_equal room.code, rematch.code
    assert_equal room.slice(:surprise, :tone, :length, :locale, :max_players), rematch.slice(:surprise, :tone, :length, :locale, :max_players)
    assert_not_equal room.place, rematch.place, "the rematch draws a fresh card"
    assert_equal users(:deniz), rematch.host.user
    assert_equal [ users(:deniz), users(:ilker), users(:sevval) ], rematch.party.map(&:user)
    assert rematch.players.none?(&:ready?)
    assert_equal sevval.user, rematch.player_for(users(:sevval)).user
  end

  test "everyone who asks for a rematch lands in the same lobby" do
    room = finished_room

    first = room.start_rematch(by: users(:deniz))

    assert_no_difference -> { GameSession.count } do
      assert_equal first, room.reload.start_rematch(by: users(:ilker))
    end
    assert_equal users(:deniz), first.host.user
  end

  test "a fallen player is one whose character has no health left" do
    room = finished_room
    players(:deniz_room_guest).character.update! hp: 0

    assert_equal [ false, true ], room.party.map(&:fallen?)
  end

  test "dice rolled counts every roll of the adventure" do
    game_session = game_sessions(:ilker_solo)
    roll_in game_session, position: 1
    roll_in game_session, position: 2

    assert_equal 2, game_session.dice_rolled
  end

  private
    def finished_room
      game_sessions(:ilker_room).tap do |room|
        room.players.each { it.ready_up(character_attributes) }
        room.update! started_at: 1.hour.ago, ended_at: Time.current
      end
    end

    def roll_in(game_session, position:, value: 15)
      scene = game_session.scenes.create!(position: position, active_player: game_session.host, state: :played)
      scene.choices.create!(label: "Press on", stat: "strength", modifier: 0, target: 11, clue: true).create_roll!(player: game_session.host, value: value)
    end

    def create_room
      GameSession.create!(creator: users(:deniz), card: "mining_town dry_well indebted_smith", max_players: GameSession::PARTY_SIZE)
    end

    def character_attributes
      { race: "human", klass: "warrior", background: "soldier",
        stats: Character::Klass.fetch("warrior").base_stats.merge("strength" => 16, "constitution" => 15, "charisma" => 14) }
    end
end
