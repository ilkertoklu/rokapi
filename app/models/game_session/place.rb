class GameSession::Place < Data.define(:key)
  extend Catalog

  translates :text

  ALL = %w[ fishing_village mining_town river_ferry steppe_camp charcoal_camp border_fort city_docks salt_caves ].map { |key| new(key: key) }.freeze
end
