class Character::Klass < Data.define(:key, :label, :description, :base_hp, :base_stats, :gear)
  extend Catalog

  ALL = [
    new(key: "warrior", label: "Warrior", description: "Fights at the front, starts with a longsword and a round shield.",
        base_hp: 26, base_stats: { "strength" => 14, "agility" => 11, "constitution" => 13, "intelligence" => 8, "wisdom" => 12, "charisma" => 12 }.freeze,
        gear: [ { name: "Longsword", kind: "passive" }, { name: "Round shield", kind: "passive" } ].freeze),
    new(key: "ranger", label: "Ranger", description: "Follows the trail and strikes from a distance, at home in the wild.",
        base_hp: 24, base_stats: { "strength" => 11, "agility" => 14, "constitution" => 12, "intelligence" => 10, "wisdom" => 14, "charisma" => 9 }.freeze,
        gear: [ { name: "Longbow", kind: "passive" }, { name: "Quiver", kind: "passive", description: "full of arrows" } ].freeze),
    new(key: "rogue", label: "Rogue", description: "Walks in shadow, untroubled by locks and traps.",
        base_hp: 22, base_stats: { "strength" => 9, "agility" => 15, "constitution" => 10, "intelligence" => 12, "wisdom" => 11, "charisma" => 13 }.freeze,
        gear: [ { name: "Short dagger", kind: "passive" }, { name: "Lockpick set", kind: "passive", description: "opens locks" } ].freeze),
    new(key: "mage", label: "Mage", description: "Carries the force of old words, fragile but devastating.",
        base_hp: 18, base_stats: { "strength" => 8, "agility" => 10, "constitution" => 10, "intelligence" => 15, "wisdom" => 14, "charisma" => 13 }.freeze,
        gear: [ { name: "Oak staff", kind: "passive" }, { name: "Spellbook", kind: "passive", description: "holds the old words" } ].freeze),
    new(key: "healer", label: "Healer", description: "Keeps companions standing, carrying the light along.",
        base_hp: 22, base_stats: { "strength" => 10, "agility" => 9, "constitution" => 13, "intelligence" => 12, "wisdom" => 15, "charisma" => 11 }.freeze,
        gear: [ { name: "Torch", kind: "passive", description: "lights the way" }, { name: "Healing potion", kind: "instant", hp_effect: 7, uses_left: 1 } ].freeze),
    new(key: "bard", label: "Bard", description: "Wields words like a weapon, dealing in morale and cunning.",
        base_hp: 20, base_stats: { "strength" => 9, "agility" => 12, "constitution" => 10, "intelligence" => 12, "wisdom" => 12, "charisma" => 15 }.freeze,
        gear: [ { name: "Lute", kind: "passive", description: "lifts spirits" } ].freeze)
  ].freeze

  def self.base_stats_by_key = by_key.transform_values(&:base_stats)
end
