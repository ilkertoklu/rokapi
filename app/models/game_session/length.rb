class GameSession::Length < Data.define(:key, :label, :scenes, :estimate)
  extend Catalog

  ALL = [
    new(key: "short", label: "Short", scenes: 7, estimate: "~15 min"),
    new(key: "medium", label: "Medium", scenes: 12, estimate: "~30 min"),
    new(key: "long", label: "Long", scenes: 18, estimate: "~60 min")
  ].freeze
end
