class GameSession::Length < Data.define(:key, :scenes)
  extend Catalog

  translates :label, :estimate

  ALL = [
    new(key: "short", scenes: 7),
    new(key: "medium", scenes: 12),
    new(key: "long", scenes: 18)
  ].freeze
end
