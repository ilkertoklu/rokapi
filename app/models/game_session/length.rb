class GameSession::Length < Data.define(:key, :label, :scenes, :estimate)
  extend Catalog

  ALL = [
    new(key: "short", label: "Kısa", scenes: 7, estimate: "~15 dk"),
    new(key: "medium", label: "Orta", scenes: 12, estimate: "~30 dk"),
    new(key: "long", label: "Uzun", scenes: 18, estimate: "~60 dk")
  ].freeze
end
