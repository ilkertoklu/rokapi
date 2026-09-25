class Character::Stat < Data.define(:key)
  extend Catalog

  translates :label, :abbreviation

  ALL = %w[ strength agility constitution intelligence wisdom charisma ].map { new(key: it) }.freeze
end
