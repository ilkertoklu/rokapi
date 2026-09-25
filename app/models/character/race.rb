class Character::Race < Data.define(:key)
  extend Catalog

  translates :label, :description

  ALL = %w[ human half_elf elf dwarf halfling tiefling ].map { new(key: it) }.freeze
end
