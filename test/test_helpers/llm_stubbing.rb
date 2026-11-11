module LlmStubbing
  SCENE_RESPONSE = <<~TEXT
    Rain hammers the inn's roof tiles. The door swings on its hinges and creaks.

    Inside, a single candle is still burning.

    ```json
    {"title": "The Old Inn", "location": "Whitebend",
     "choices": [
       {"label": "Read the dusty ledger", "stat": "intelligence", "difficulty": 10, "clue": true},
       {"label": "Force the drawer open", "stat": "strength", "difficulty": 14},
       {"label": "Listen at the stable in silence", "stat": "wisdom", "difficulty": 12}
     ]}
    ```
  TEXT

  PLAN_RESPONSE = <<~TEXT
    Question: Will the hero find the lost child before the tide comes in?
    Truth: The child's mother hid him in the lighthouse to keep him from the press gang.
  TEXT

  PLANNING = [ PLAN_RESPONSE, "none" ].freeze

  SECOND_SCENE_RESPONSE = SCENE_RESPONSE.sub('"title": "The Old Inn"', '"title": "The Stable"')
    .sub("Rain hammers the inn's roof tiles", "The stable door is barred from the inside")

  OUTCOME_RESPONSE = <<~TEXT
    The drawer opens, but you cut your hand.

    ```json
    {"hp": -4}
    ```
  TEXT

  ENDING_RESPONSE = <<~TEXT
    The drawer gives, and the caravan bells echo down the valley as you ride into Whitebend.

    ```json
    {"outcome": "victory"}
    ```
  TEXT

  class ScriptedReplies < RubyLLM::Protocol
    cattr_accessor :replies, :requests

    def complete(messages, **)
      raise RubyLLM::ConfigurationError, "No replies scripted; wrap the call in stub_llm" unless replies

      system, conversation = messages.partition { it.role == :system }
      requests << { "system" => system.map(&:content).join("\n\n").presence, "prompt" => transcript(conversation) }
      reply = replies[requests.size - 1] or raise RubyLLM::ServerError, "No reply scripted for call #{requests.size}"

      reply.each_line { yield RubyLLM::Chunk.new(role: :assistant, content: it, model_id: model.id) } if block_given?
      RubyLLM::Message.new(role: :assistant, content: reply, model: model.id, cost: RubyLLM::Cost.new(total: 0))
    end

    private
      def transcript(conversation)
        *earlier, latest = conversation
        return latest.content if earlier.empty?

        turns = earlier.map { |message| "<#{message.role}>\n#{message.content}\n</#{message.role}>" }
        "<conversation_so_far>\n#{turns.join("\n")}\n</conversation_so_far>\n\n#{latest.content}"
      end
  end

  def stub_llm(*replies)
    ScriptedReplies.replies = replies
    ScriptedReplies.requests = []
    yield
    ScriptedReplies.requests
  ensure
    ScriptedReplies.replies = nil
  end
end
