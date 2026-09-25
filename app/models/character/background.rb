class Character::Background < Data.define(:key)
  extend Catalog

  translates :label, :description

  ALL = %w[ soldier criminal scholar noble traveler artisan ].map { new(key: it) }.freeze
end
