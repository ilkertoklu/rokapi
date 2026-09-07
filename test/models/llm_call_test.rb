require "test_helper"

class LlmCallTest < ActiveSupport::TestCase
  test "a response without a price is not recorded as free" do
    response = RubyLLM::Message.new(role: :assistant, content: "x", model_id: "no-such-model",
                                    input_tokens: 10, output_tokens: 10)

    assert_raises NoMethodError do
      LlmCall.record game_session: game_sessions(:ilker_solo), purpose: :scene, response: response
    end
    assert_empty game_sessions(:ilker_solo).llm_calls
  end
end
