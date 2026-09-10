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

  PLAN_RESPONSE = %({"title": "Blizzard Salt", "premise": "Whitebend goes into winter without salt.", "personal_stake": "An old debt to Sergeant Sherrick.",
    "antagonist": {"name": "Nail Aral", "want": "To protect the bridge.", "method": "He uses the lodges.", "first_sign": "Cut straps."},
    "ally": {"name": "Elif", "want": "To find her brother.", "secret": "Nail is her father."},
    "twist": "Not an ambush, a warning.",
    "beats": ["The mule comes back.", "The tracks break off on stone.", "A wounded driver.", "Elif confesses.", "The bridge footing is cracked.", "Face to face with Nail.", "The caravan crosses lightened."],
    "finale_question": "Will the salt reach the village?", "victory": "Enough salt comes down.", "defeat": "The bridge goes."})

  FINALE_RESPONSE = <<~TEXT
    ```json
    {"title": "The Return", "location": "Whitebend", "choices": [], "finale": true, "outcome": "victory"}
    ```

    The caravan bells echo down the valley as you ride into Whitebend.
  TEXT

  def stub_llm(*chats)
    queue = chats.flatten
    original = RubyLLM.method(:chat)
    RubyLLM.singleton_class.define_method(:chat) { |*, **| queue.size > 1 ? queue.shift : queue.first }
    yield
  ensure
    RubyLLM.singleton_class.define_method(:chat, original)
  end
end

class FakeChat
  attr_reader :prompt

  def initialize(text, model_id: "gpt-5.1", chunks: nil, input_tokens: 1000, output_tokens: 500, &after_chunk)
    @text = text
    @model_id = model_id
    @chunks = chunks || [ text ]
    @input_tokens = input_tokens
    @output_tokens = output_tokens
    @after_chunk = after_chunk
  end

  def self.split_at_structure(text, &after_chunk)
    closing = text.index("```", 3) + 3
    new(text, chunks: [ text[0...closing], text[closing..] ], &after_chunk)
  end

  def with_instructions(*)
    self
  end

  def with_schema(*)
    @schema = true
    self
  end

  def ask(prompt)
    @prompt = prompt

    if block_given?
      @chunks.each do |chunk|
        yield RubyLLM::Chunk.new(role: :assistant, content: chunk)
        @after_chunk&.call
      end
    end

    message = RubyLLM::Message.new(role: :assistant, content: @text, model_id: @model_id,
                                   input_tokens: @input_tokens, output_tokens: @output_tokens)
    message.content = structured_content if @schema
    message
  end

  private
    def structured_content
      JSON.parse(@text)
    rescue JSON::ParserError
      @text
    end
end
