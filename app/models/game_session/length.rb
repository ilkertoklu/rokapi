class GameSession::Length < Data.define(:key, :scenes, :title_length)
  extend Catalog

  translates :label, :estimate

  ALL = [
    new(key: "short", scenes: 7, title_length: 30),
    new(key: "medium", scenes: 12, title_length: 22),
    new(key: "long", scenes: 18, title_length: 12)
  ].freeze
end
