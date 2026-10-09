class GameSession::Quest < Data.define(:key)
  extend Catalog

  translates :title, :hook, :brief

  ALL = [
    new(key: "lost_caravan"),
    new(key: "sunken_village")
  ].freeze
end
