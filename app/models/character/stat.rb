class Character::Stat < Data.define(:key, :label, :abbreviation)
  extend Catalog

  ALL = [
    new(key: "strength", label: "Strength", abbreviation: "STR"),
    new(key: "agility", label: "Agility", abbreviation: "AGI"),
    new(key: "constitution", label: "Constitution", abbreviation: "CON"),
    new(key: "intelligence", label: "Intelligence", abbreviation: "INT"),
    new(key: "wisdom", label: "Wisdom", abbreviation: "WIS"),
    new(key: "charisma", label: "Charisma", abbreviation: "CHA")
  ].freeze
end
