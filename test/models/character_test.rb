require "test_helper"

class CharacterTest < ActiveSupport::TestCase
  setup do
    @player = players(:ilker_without_character_host)
    @base = Character::Klass.fetch("warrior").base_stats
  end

  test "class base stats are balanced and complete" do
    sums = Character::Klass.all.map { |klass| klass.base_stats.values.sum }
    assert_equal 1, sums.uniq.size

    Character::Klass.all.each do |klass|
      assert_equal Character::Stat.keys.sort, klass.base_stats.keys.sort
    end
  end

  test "valid character derives hp from class and constitution" do
    character = @player.create_character!(
      race: "human", klass: "warrior", background: "soldier",
      stats: @base.merge("strength" => 16, "constitution" => 15, "charisma" => 14)
    )

    assert_equal 26 + (15 - 10), character.max_hp
    assert_equal character.max_hp, character.hp
  end

  test "rejects allocations that do not spend exactly the free points" do
    assert_not build_character(@base).valid?
    assert_not build_character(@base.merge("strength" => 18, "agility" => 15)).valid?
  end

  test "rejects stats below class base or above the cap" do
    assert_not build_character(@base.merge("strength" => 13, "agility" => 18)).valid?
    assert_not build_character(@base.merge("strength" => 20)).valid?
  end

  test "bonus_for follows the modifier formula" do
    character = characters(:ilker_hero)

    assert_equal 3, character.bonus_for("strength")
    assert_equal(-1, character.bonus_for("intelligence"))
    assert_equal 1, character.bonus_for("wisdom")
  end

  test "a new character carries the class starting gear" do
    base = Character::Klass.fetch("healer").base_stats
    character = @player.create_character!(
      race: "human", klass: "healer", background: "soldier",
      stats: base.merge("wisdom" => 18, "constitution" => 16)
    )

    torch = character.items.find_by!(name: "Torch")
    assert torch.passive?
    assert_equal "Lights the way", torch.description

    potion = character.items.find_by!(name: "Healing potion")
    assert potion.usable?
    assert_equal 7, potion.hp_effect
  end

  test "a regained status replaces its namesake instead of stacking" do
    character = characters(:ilker_hero)
    character.gain_status(name: "Soaked Through", modifier: -2, turns_left: 2)
    character.gain_status(name: "Soaked Through", modifier: -1, turns_left: 3)

    soaked = character.status_effects.where(name: "Soaked Through").sole
    assert_equal(-1, soaked.modifier)
    assert_equal 3, soaked.turns_left
  end

  test "losing takes carried items and statuses, never spent history" do
    character = characters(:ilker_hero)
    character.status_effects.create! name: "Dragging Leg", modifier: -1, expires_when: "until it eases"
    items(:healing_potion).use

    character.lose_item "Inn ledger"
    character.lose_item "Healing potion"
    character.lose_status "Dragging Leg"

    assert_not character.items.exists?(name: "Inn ledger")
    assert character.items.exists?(name: "Healing potion"), "a spent item is history, not inventory"
    assert_not character.status_effects.exists?(name: "Dragging Leg")
  end

  test "damage and healing stay within 0 and max hp" do
    character = characters(:ilker_hero)

    character.adjust_hp(-99)
    assert_equal 0, character.hp

    character.adjust_hp(99)
    assert_equal character.max_hp, character.hp
  end

  test "rejects unknown options" do
    character = build_character(@base.merge("strength" => 20), race: "orc")
    assert_not character.valid?
    assert character.errors[:race].any?
  end

  private
    def build_character(stats, race: "human")
      @player.build_character(race: race, klass: "warrior", background: "soldier", stats: stats)
    end
end
