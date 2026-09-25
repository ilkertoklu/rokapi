require "test_helper"

class LlmCallTest < ActiveSupport::TestCase
  test "a response without a price is recorded with an unknown cost, not as free" do
    response = RubyLLM::Message.new(role: :assistant, content: "x", model: "no-such-model",
                                    input_tokens: 10, output_tokens: 10)

    call = LlmCall.record game_session: game_sessions(:ilker_solo), purpose: :scene, response: response

    assert_nil call.cost_in_microdollars
    assert_equal [ 10, 10 ], [ call.input_tokens, call.output_tokens ]
  end

  test "a response without reported usage is recorded with unknown tokens, not zero" do
    response = RubyLLM::Message.new(role: :assistant, content: "x", model: "gpt-5-mini")

    call = LlmCall.record game_session: game_sessions(:ilker_solo), purpose: :scene, response: response

    assert_nil call.input_tokens
    assert_nil call.output_tokens
    assert_nil call.cost_in_microdollars
  end
end
