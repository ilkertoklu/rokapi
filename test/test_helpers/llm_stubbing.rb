module LlmStubbing
  SCENE_RESPONSE = <<~TEXT
    Rain hammers the inn's roof tiles. The door swings on its hinges and creaks.

    Inside, a single candle is still burning.

    ```json
    {"title": "The Old Inn", "location": "Whitebend",
     "choices": [
       {"label": "Read the dusty ledger", "stat": "intelligence", "difficulty": 10},
       {"label": "Force the drawer open", "stat": "strength", "difficulty": 14},
       {"label": "Listen at the stable in silence", "stat": "wisdom", "difficulty": 12}
     ]}
    ```
  TEXT

  SECOND_SCENE_RESPONSE = SCENE_RESPONSE.sub('"title": "The Old Inn"', '"title": "The Stable"')
    .sub("Rain hammers the inn's roof tiles", "The stable door is barred from the inside")

  OUTCOME_RESPONSE = <<~TEXT
    The drawer opens, but you cut your hand.

    ```json
    {"hp": -4}
    ```
  TEXT

  FINALE_RESPONSE = <<~TEXT
    The caravan bells echo down the valley as you ride into Whitebend.

    ```json
    {"title": "The Return", "location": "Whitebend", "outcome": "victory"}
    ```
  TEXT

  def stub_understudy(*replies)
    Dir.mktmpdir("understudy") do |dir|
      replies.each_with_index { |reply, call| File.write(File.join(dir, "reply-#{call}"), reply) unless reply.nil? }
      Rails.configuration.x.narrator_command = Shellwords.join([ Rails.root.join("test/fixtures/files/understudy").to_s, dir ])
      yield
      Dir[File.join(dir, "request-*.json")].sort_by { File.basename(it)[/\d+/].to_i }.map { JSON.parse File.read(it) }
    ensure
      Rails.configuration.x.narrator_command = nil
    end
  end
end
