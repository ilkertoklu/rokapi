class Character::Stat < Data.define(:key, :label, :abbreviation)
  extend Catalog

  ALL = [
    new(key: "strength", label: "Güç", abbreviation: "GÜÇ"),
    new(key: "agility", label: "Çeviklik", abbreviation: "ÇEV"),
    new(key: "constitution", label: "Dayanıklılık", abbreviation: "DAY"),
    new(key: "intelligence", label: "Zekâ", abbreviation: "ZEK"),
    new(key: "wisdom", label: "Sezgi", abbreviation: "SEZ"),
    new(key: "charisma", label: "Karizma", abbreviation: "KAR")
  ].freeze
end
