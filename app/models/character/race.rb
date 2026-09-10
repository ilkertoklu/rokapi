class Character::Race < Data.define(:key, :label, :description)
  extend Catalog

  ALL = [
    new(key: "human", label: "Human", description: "Versatile and balanced, at home in any class."),
    new(key: "half_elf", label: "Half-elf", description: "A child of two worlds, adaptable and intuitive."),
    new(key: "elf", label: "Elf", description: "Nimble and keen-eared, the forest's quiet step."),
    new(key: "dwarf", label: "Dwarf", description: "Hardy and stubborn, as solid as stone."),
    new(key: "halfling", label: "Halfling", description: "Small, quick and lucky, easily overlooked."),
    new(key: "tiefling", label: "Tiefling", description: "Mysterious and magnetic, an old fire burning inside.")
  ].freeze
end
