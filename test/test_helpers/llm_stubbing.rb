module LlmStubbing
  SCENE_RESPONSE = <<~TEXT
    ```json
    {"title": "The Old Inn", "location": "Whitebend",
     "choices": [
       {"label": "Read the dusty ledger", "stat": "intelligence", "difficulty": 10, "difficulty_reason": "The dust lies thick"},
       {"label": "Force the drawer open", "stat": "strength", "difficulty": 14, "difficulty_reason": "The lock is old"},
       {"label": "Listen at the stable in silence", "stat": "wisdom", "difficulty": 12, "difficulty_reason": "The wind is howling"}
     ],
     "finale": false, "outcome": null}
    ```

    Rain hammers the inn's roof tiles. The door swings on its hinges and creaks.

    Inside, a single candle is still burning.
  TEXT

  SECOND_SCENE_RESPONSE = SCENE_RESPONSE.sub('"title": "The Old Inn"', '"title": "The Stable"')
    .sub("Rain hammers the inn's roof tiles", "The stable door is barred from the inside")

  OUTCOME_RESPONSE = %({"resolution": "The drawer opens, but you cut your hand.", "effects": {"hp": -4}})

  FINALE_RESPONSE = <<~TEXT
    ```json
    {"title": "The Return", "location": "Whitebend", "choices": [], "finale": true, "outcome": "victory"}
    ```

    The caravan bells echo down the valley as you ride into Whitebend.
  TEXT

  def stub_llm(*replies)
    queue = replies.flatten
    original = RubyLLM::Provider.instance_method(:complete)
    RubyLLM::Provider.define_method(:complete) { |messages, **, &block| (queue.size > 1 ? queue.shift : queue.first).reply(messages, &block) }
    yield
  ensure
    RubyLLM::Provider.define_method(:complete, original)
  end

  def stub_understudy(reply)
    Tempfile.create("reply") do |file|
      file.write reply
      file.close

      Rails.configuration.x.narrator_command = understudy_command(file.path)
      yield
    ensure
      Rails.configuration.x.narrator_command = nil
    end
  end

  def understudy_command(reply_path)
    Shellwords.join [ Rails.root.join("test/fixtures/files/understudy").to_s, reply_path ]
  end
end

class FakeReply
  attr_reader :messages

  def initialize(text, model: "gpt-5-nano", chunks: nil, input_tokens: 1000, output_tokens: 500, &after_chunk)
    @text = text
    @model = model
    @chunks = chunks || [ text ]
    @input_tokens = input_tokens
    @output_tokens = output_tokens
    @after_chunk = after_chunk
  end

  def self.split_at_structure(text, &after_chunk)
    closing = text.index("```", 3) + 3
    new(text, chunks: [ text[0...closing], text[closing..] ], &after_chunk)
  end

  def self.failing(error)
    new("").tap { |fake| fake.define_singleton_method(:reply) { |*| raise error } }
  end

  def prompt
    @messages.last.content
  end

  def instructions
    @messages.select { |message| message.role == :system }.map(&:content).join("\n\n")
  end

  def reply(messages)
    @messages = messages.dup

    if block_given?
      @chunks.each do |chunk|
        yield RubyLLM::Chunk.new(role: :assistant, content: chunk)
        @after_chunk&.call
      end
    end

    RubyLLM::Message.new(role: :assistant, content: @text, model: @model,
                         input_tokens: @input_tokens, output_tokens: @output_tokens)
  end
end
