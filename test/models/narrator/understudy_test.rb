require "test_helper"

class Narrator::UnderstudyTest < ActiveSupport::TestCase
  test "the command receives the system prompt, the user prompt and the schema as JSON" do
    response = Narrator::Understudy.new("cat").with_instructions("Be the narrator.")
      .with_schema(Narrator::OutcomeSchema).ask("Resolve the roll.")

    request = JSON.parse(response.content)
    assert_equal "Be the narrator.", request["system"]
    assert_equal "Resolve the roll.", request["prompt"]
    assert_equal "object", request.dig("schema", "type")
    assert_includes request.dig("schema", "properties").keys, "resolution"
    assert_not request["schema"].key?("$schema"), "the schema is sent as the API gets it, without metadata"
  end

  test "a chat meant for another model tells the command which" do
    assert_equal "claude-opus-5-5", JSON.parse(Narrator::Understudy.new("cat").with_model("claude-opus-5-5").ask("Judge.").content)["model"]
    assert_nil JSON.parse(Narrator::Understudy.new("cat").ask("Write the scene.").content)["model"]
  end

  test "a reply without a schema is asked for without one" do
    request = JSON.parse(Narrator::Understudy.new("cat").ask("Write the scene.").content)

    assert_nil request["schema"]
    assert_nil request["system"]
  end

  test "what the command writes as it goes is relayed as chunks" do
    reply = "Kar fırtınası köyü sardı; çığ düştü. " * 20
    chunks = []

    response = stub_understudy(reply) do
      Narrator::Understudy.new(Rails.configuration.x.narrator_command).ask("Write the scene.") { chunks << it.content }
    end

    assert_operator chunks.size, :>, 1
    assert chunks.all?(&:valid_encoding?)
    assert_equal reply, chunks.join
    assert_equal reply, response.content
  end

  test "the reply is the understudy's and costs nothing" do
    response = Narrator::Understudy.new("printf '{\"resolution\": \"Done.\"}'").ask("Resolve the roll.")

    assert_equal "understudy", response.model
    assert_equal 0, response.cost.total
    assert_equal({ "resolution" => "Done." }, response.parsed)
  end

  test "a failing command raises" do
    assert_raises Narrator::Understudy::Failure do
      Narrator::Understudy.new("cat > /dev/null; exit 3").ask("Write the scene.")
    end
  end
end
