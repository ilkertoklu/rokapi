class GameSession::Place < Data.define(:key)
  extend Catalog

  translates :text

  ALL = %w[
    fishing_village mining_town river_ferry steppe_camp charcoal_camp border_fort city_docks salt_caves
    lighthouse_rock merchant_ship snowbound_pass cliff_monastery stilt_village desert_caravanserai
    buried_tunnels tanners_quarter keep_kitchens frozen_lake_lodge prison_island burial_mounds
  ].map { |key| new(key: key) }.freeze
end
