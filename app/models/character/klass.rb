class Character::Klass < Data.define(:key, :base_hp, :base_stats, :gear)
  extend Catalog

  translates :label, :description

  ALL = [
    new(key: "warrior", base_hp: 26,
        base_stats: { "strength" => 14, "agility" => 11, "constitution" => 13, "intelligence" => 8, "wisdom" => 12, "charisma" => 12 }.freeze,
        gear: [ { key: "longsword", kind: "passive" }, { key: "round_shield", kind: "passive" } ].freeze),
    new(key: "ranger", base_hp: 24,
        base_stats: { "strength" => 11, "agility" => 14, "constitution" => 12, "intelligence" => 10, "wisdom" => 14, "charisma" => 9 }.freeze,
        gear: [ { key: "longbow", kind: "passive" }, { key: "quiver", kind: "passive" } ].freeze),
    new(key: "rogue", base_hp: 22,
        base_stats: { "strength" => 9, "agility" => 15, "constitution" => 10, "intelligence" => 12, "wisdom" => 11, "charisma" => 13 }.freeze,
        gear: [ { key: "short_dagger", kind: "passive" }, { key: "lockpick_set", kind: "passive" } ].freeze),
    new(key: "mage", base_hp: 18,
        base_stats: { "strength" => 8, "agility" => 10, "constitution" => 10, "intelligence" => 15, "wisdom" => 14, "charisma" => 13 }.freeze,
        gear: [ { key: "oak_staff", kind: "passive" }, { key: "spellbook", kind: "passive" } ].freeze),
    new(key: "healer", base_hp: 22,
        base_stats: { "strength" => 10, "agility" => 9, "constitution" => 13, "intelligence" => 12, "wisdom" => 15, "charisma" => 11 }.freeze,
        gear: [ { key: "torch", kind: "passive" }, { key: "healing_potion", kind: "instant", hp_effect: 7, uses_left: 1 } ].freeze),
    new(key: "bard", base_hp: 20,
        base_stats: { "strength" => 9, "agility" => 12, "constitution" => 10, "intelligence" => 12, "wisdom" => 12, "charisma" => 15 }.freeze,
        gear: [ { key: "lute", kind: "passive" } ].freeze)
  ].freeze

  def self.base_stats_by_key = by_key.transform_values(&:base_stats)

  def starting_items(locale:)
    gear.map do |piece|
      scope = [ "character.gear", piece[:key] ]
      name = I18n.t(:name, scope:, locale:)
      description = I18n.t(:description, scope:, locale:, default: nil)

      piece.except(:key).merge(name:, description:)
    end
  end
end
