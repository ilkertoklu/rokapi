module LlmStubbing
  SCENE_RESPONSE = <<~TEXT
    ```json
    {"title": "Eski Han", "location": "Akçabük",
     "choices": [
       {"label": "Tozlu defteri oku", "stat": "intelligence", "difficulty": 10, "difficulty_label": "kolay", "difficulty_reason": "Toz kalın"},
       {"label": "Çekmeceyi zorla", "stat": "strength", "difficulty": 14, "difficulty_label": "orta", "difficulty_reason": "Kilit eski"},
       {"label": "Ahırı sessizce dinle", "stat": "wisdom", "difficulty": 12, "difficulty_label": "orta", "difficulty_reason": "Rüzgâr uğulduyor"}
     ],
     "finale": false, "outcome": null}
    ```

    Yağmur hanın kiremitlerini dövüyor; kapı menteşelerinden gıcırdayarak sallanıyor.

    İçeride tek bir mum hâlâ yanıyor.
  TEXT

  SECOND_SCENE_RESPONSE = SCENE_RESPONSE.sub('"title": "Eski Han"', '"title": "Ahır"')
    .sub("Yağmur hanın kiremitlerini dövüyor", "Ahırın kapısı içeriden sürgülenmiş")

  OUTCOME_RESPONSE = %({"resolution": "Çekmece açıldı ama elini kestin.", "effects": {"hp": -4}})

  FINALE_RESPONSE = <<~TEXT
    ```json
    {"title": "Dönüş", "location": "Akçabük", "choices": [], "finale": true, "outcome": "victory"}
    ```

    Kervan çanları vadide yankılanırken Akçabük'e girdiniz.
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
    message.content = JSON.parse(@text) if @schema
    message
  end
end
