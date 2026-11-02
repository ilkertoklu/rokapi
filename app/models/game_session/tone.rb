class GameSession::Tone < Data.define(:key)
  extend Catalog

  translates :label

  ALL = %w[fun balanced dark].map { |key| new(key: key) }.freeze
end
