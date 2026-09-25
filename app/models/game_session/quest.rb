class GameSession::Quest < Data.define(:key, :glyph)
  extend Catalog

  translates :title, :hook, :brief

  ALL = [
    new(key: "lost_caravan", glyph: "bell"),
    new(key: "sunken_village", glyph: "compass")
  ].freeze
end
