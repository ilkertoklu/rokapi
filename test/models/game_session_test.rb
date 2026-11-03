require "test_helper"
require "turbo/broadcastable/test_helper"

class GameSessionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper, Turbo::Broadcastable::TestHelper

  test "creating a session enrolls the creator" do
    game_session = GameSession.create!(creator: users(:ilker), quest: "sunken_village")

    assert_equal users(:ilker), game_session.players.sole.user
    assert_equal game_session.players.sole, game_session.host
    assert_not game_session.started?
  end

  test "a new session keeps the language it was started in" do
    game_session = I18n.with_locale(:tr) { GameSession.create!(creator: users(:ilker), quest: "sunken_village") }

    assert_equal "tr", game_session.locale
    assert_not GameSession.new(creator: users(:ilker), locale: "xx").valid?
  end

  test "title falls back for surprise adventures" do
    assert_equal "The Lost Caravan", game_sessions(:ilker_solo).title
    assert_equal "Surprise adventure", GameSession.new.title
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
    room = GameSession.create!(creator: users(:ilker), quest: "sunken_village", max_players: GameSession::PARTY_SIZE)

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

  test "only the host starts a room, and only once everyone is ready" do
    room = game_sessions(:ilker_room)
    players(:ilker_room_host).ready_up(character_attributes)

    assert_not room.everyone_ready?
    assert_raises(GameSession::NotReady) { room.start(by: players(:ilker_room_host)) }

    players(:deniz_room_guest).ready_up(character_attributes)
    assert_raises(GameSession::NotReady) { room.start(by: players(:deniz_room_guest)) }
    assert_not room.reload.started?

    assert_enqueued_with job: Scene::NarrateJob do
      room.start(by: players(:ilker_room_host))
    end
    assert room.reload.started?
    assert_equal players(:ilker_room_host), room.scenes.sole.active_player
  end

  test "turns rotate through the party in join order, up to the last scene" do
    room = game_sessions(:ilker_room)
    sevval = room.join(users(:sevval))
    room.players.each { it.ready_up(character_attributes) }

    room.start(by: players(:ilker_room_host))
    (room.scene_budget - 1).times { room.advance }

    host, deniz = players(:ilker_room_host), players(:deniz_room_guest)
    assert_equal [ host, deniz, sevval, host, deniz, sevval, host ], room.scenes.chronological.map(&:active_player)
  end

  test "the last roll counts twice toward the verdict and settles a tie" do
    assert_equal "victory", verdict_after(15, 15, 5, 5, 15)
    assert_equal "defeat", verdict_after(15, 15, 15, 5, 5)
    assert_equal "victory", verdict_after(15, 15, 15, 15, 5)
    assert_equal "defeat", verdict_after(5, 5, 5, 15)
  end

  test "a catastrophe on the last roll always loses and a critical always wins" do
    assert_equal "defeat", verdict_after(15, 15, 15, 15, 1)
    assert_equal "victory", verdict_after(5, 5, 5, 5, 20)
  end

  test "solo play stays with the host every scene" do
    game_session = game_sessions(:ilker_without_character)
    players(:ilker_without_character_host).ready_up(character_attributes)
    3.times { game_session.advance }

    assert game_session.reload.started?
    assert_equal [ players(:ilker_without_character_host) ], game_session.scenes.map(&:active_player).uniq
  end

  test "a rematch opens a fresh lobby with the same party and settings" do
    room = finished_room
    sevval = room.players.create!(user: users(:sevval))

    rematch = room.start_rematch(by: users(:deniz))

    assert_not rematch.started?
    assert rematch.lobby?
    assert_not_equal room.code, rematch.code
    assert_equal room.slice(:quest, :tone, :length, :locale, :max_players), rematch.slice(:quest, :tone, :length, :locale, :max_players)
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

  test "survivors are the players whose characters still stand" do
    room = finished_room
    players(:deniz_room_guest).character.update! hp: 0

    assert_equal [ players(:ilker_room_host) ], room.survivors
  end

  private
    def verdict_after(*values)
      game_session = GameSession.create!(creator: users(:ilker), quest: "lost_caravan")

      values.each.with_index(1) do |value, position|
        scene = game_session.scenes.create!(position: position, active_player: game_session.host, state: :played)
        scene.choices.create!(label: "Press on", stat: "strength", modifier: 0, target: 11).create_roll!(player: game_session.host, value: value)
      end

      game_session.verdict
    end

    def finished_room
      game_sessions(:ilker_room).tap do |room|
        room.players.each { it.ready_up(character_attributes) }
        room.update! started_at: 1.hour.ago, ended_at: Time.current
      end
    end

    def create_room
      GameSession.create!(creator: users(:deniz), quest: "sunken_village", max_players: GameSession::PARTY_SIZE)
    end

    def character_attributes
      { race: "human", klass: "warrior", background: "soldier",
        stats: Character::Klass.fetch("warrior").base_stats.merge("strength" => 16, "constitution" => 15, "charisma" => 14) }
    end
end
