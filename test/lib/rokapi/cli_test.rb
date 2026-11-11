require "test_helper"
require Rails.root.join("lib/rokapi/cli")

class Rokapi::CLITest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  class Transport
    attr_accessor :game_id

    def initialize(test)
      @test = test
    end

    def logged_in? = true

    def get(path) = deliver(:get, path)
    def post(path, params = {}) = deliver(:post, path, params)

    private
      def deliver(verb, path, params = nil)
        @test.public_send verb, path, params: params, as: :json
        response = @test.response

        Rokapi::Client::Response.new(status: response.status, location: response.location, content_type: response.content_type, body: response.body)
      end
  end

  setup do
    @game_session = game_sessions(:ilker_solo)
    @scene = @game_session.scenes.create!(position: 1, active_player: players(:ilker_solo_host), state: :choosing, title: "The Old Inn", narration: "Rain hammers the roof.")
    @scene.choices.create! label: "Force the drawer open", stat: "strength", modifier: 3, target: 14
    @scene.choices.create! label: "Read the dusty ledger", stat: "intelligence", modifier: -1, target: 10

    sign_in_as users(:ilker)
  end

  test "show lays out the scene, its choices and the next step" do
    output = play(:show)

    assert_match "=== SCENE 1/7 — The Old Inn", output
    assert_match "1) [strength +3 | hard, target 14] Force the drawer open", output
    assert_match "Next: bin/rokapi choose 1|2 (or use ITEM)", output
  end

  test "rolling waits for the narrator and shows the outcome" do
    @scene.choices.first.choose

    output = nil
    stub_llm(OUTCOME_RESPONSE) do
      with_die(15) { perform_enqueued_jobs { output = play(:roll) } }
    end

    assert_match "ROLL: d20=15 +3 = 18 vs 14 → SOLID", output
    assert_match "RESULT: The drawer opens, but you cut your hand.", output
    assert_match "Next: bin/rokapi continue", output
  end

  test "a move after the game is over is refused with why" do
    @game_session.finish

    error = assert_raises(Thor::Error) { play(:roll) }
    assert_equal "The game is over. Run: bin/rokapi show", error.message
  end

  test "in a room, show reports the other hero's turn until it is yours" do
    room = game_sessions(:ilker_room)
    room.players.each { ready_warrior it }
    room.start
    room.current_scene.update! state: :choosing, narration: "The tide turns."
    sign_in_as users(:deniz)

    assert_output(/>>> Ilker’s turn/) do
      error = assert_raises(Thor::Error) { cli(game: room, wait: 0).show }
      assert_equal "Still not your turn after 0s. Run: bin/rokapi show", error.message
    end
  end

  private
    def play(command)
      capture_io { cli.public_send(command) }.first
    end

    def cli(game: @game_session, wait: 1)
      Rokapi::CLI.new([], [ "--game", game.id.to_s, "--wait", wait.to_s ]).tap do
        it.instance_variable_set :@client, Transport.new(self)
      end
    end
end
