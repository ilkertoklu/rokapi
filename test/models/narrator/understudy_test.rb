require "test_helper"

class Narrator::UnderstudyTest < ActiveSupport::TestCase
  setup do
    @chat = Narrator::Conversation.create!(game_session: game_sessions(:ilker_solo), model: Narrator::Understudy::MODEL,
      provider: :understudy, assume_model_exists: true)
  end

  test "the command receives the system prompt, the user prompt and the schema as JSON" do
    request = with_command("cat") do
      JSON.parse @chat.with_instructions("Be the narrator.").with_schema(Narrator::OutcomeSchema).ask("Resolve the roll.").content
    end

    assert_equal "Be the narrator.", request["system"]
    assert_equal "Resolve the roll.", request["prompt"]
    assert_equal "object", request.dig("schema", "type")
    assert_includes request.dig("schema", "properties").keys, "resolution"
    assert_not request["schema"].key?("$schema"), "the schema is sent as the API gets it, without metadata"
  end

  test "a reply without a schema is asked for without one" do
    request = with_command("cat") { JSON.parse @chat.ask("Write the scene.").content }

    assert_nil request["schema"]
    assert_nil request["system"]
  end

  test "earlier turns reach the command as the conversation so far" do
    request = with_command("cat") do
      @chat.with_instructions("Be the narrator.").ask("Scene 1 of 7. Write the first scene.")
      JSON.parse Narrator::Conversation.find(@chat.id).ask("Scene 2 of 7. Write the next scene.").content
    end

    assert_equal "Be the narrator.", request["system"]
    assert request["prompt"].start_with?("<conversation_so_far>\n<user>\nScene 1 of 7. Write the first scene.\n</user>\n<assistant>\n{")
    assert request["prompt"].end_with?("</conversation_so_far>\n\nScene 2 of 7. Write the next scene.")
  end

  test "what the command writes as it goes is relayed line by line" do
    reply = "Kar fırtınası köyü sardı.\nÇığ düştü, yol kapandı.\n"
    chunks = []

    response = stub_understudy(reply) { @chat.ask("Write the scene.") { chunks << it.content } }

    assert_equal [ "Kar fırtınası köyü sardı.\n", "Çığ düştü, yol kapandı.\n" ], chunks
    assert_equal reply, chunks.join
    assert_equal reply, response.content
  end

  test "the reply is the understudy's, costs nothing and is kept" do
    response = with_command("printf '{\"resolution\": \"Done.\"}'") { @chat.ask("Resolve the roll.") }

    assert_equal "understudy", response.model
    assert_equal 0, response.cost.total
    assert_equal({ "resolution" => "Done." }, response.parsed)
    assert_equal %w[user assistant], @chat.messages.pluck(:role)
  end

  test "a failing command raises" do
    assert_raises Narrator::Understudy::Failure do
      with_command("cat > /dev/null; exit 3") { @chat.ask("Write the scene.") }
    end
  end

  private
    def with_command(command)
      Rails.configuration.x.narrator_command = command
      yield
    ensure
      Rails.configuration.x.narrator_command = nil
    end
end
