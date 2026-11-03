class GameSession::Figure < Data.define(:key)
  extend Catalog

  translates :text

  ALL = %w[ weather_reader young_guard indebted_smith unwilling_heir ambitious_clerk path_child old_captain doubted_healer ].map { |key| new(key: key) }.freeze
end
