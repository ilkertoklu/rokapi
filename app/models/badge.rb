class Badge < Data.define(:key)
  extend Catalog

  translates :name, :description

  ALL = %w[
    natural_twenty_finale last_health whole_party surprise won_back
    no_items two_twenties every_roll natural_one_finale fallen_hero
  ].map { |key| new(key: key) }.freeze
end
