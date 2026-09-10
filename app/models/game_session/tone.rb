class GameSession::Tone < Data.define(:key, :label, :directive)
  extend Catalog

  ALL = [
    new(key: "fun", label: "Fun",
        directive: "Fun — the pace is light, the humour comes out of situations and dialogue, a joke or two per scene is enough, and it holds even as the tension climbs (there is a dry line even at the climax and in the finale). The world is still real, the danger is taken seriously, and it never slides into parody."),
    new(key: "balanced", label: "Balanced",
        directive: "Balanced — classic adventure: hope and danger in balance, and the taste of victory comes with its price."),
    new(key: "dark", label: "Dark",
        directive: "Dark — the shadows weigh heavy, the costs are harsh, trust is hard won, and the horror stays within PEGI-12.")
  ].freeze
end
