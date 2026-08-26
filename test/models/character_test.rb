require "test_helper"

class CharacterTest < ActiveSupport::TestCase
  setup do
    @player = players(:ilker_without_character_host)
    @base = Character.base_stats_for("warrior")
  end

  test "class base stats are balanced and complete" do
    sums = Character::Klass.all.map { |klass| klass.base_stats.values.sum }
    assert_equal 1, sums.uniq.size

    Character::Klass.all.each do |klass|
      assert_equal Character::STAT_KEYS.sort, klass.base_stats.keys.sort
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
    base = Character.base_stats_for("healer")
    character = @player.create_character!(
      race: "human", klass: "healer", background: "soldier",
      stats: base.merge("wisdom" => 18, "constitution" => 16)
    )

    torch = character.items.find_by!(name: "Meşale")
    assert torch.passive?
    assert_equal "Çevreyi aydınlatır", torch.description

    potion = character.items.find_by!(name: "Şifa iksiri")
    assert potion.usable?
    assert_equal 7, potion.hp_effect
  end

  test "a gained item arrives with at least one use" do
    ointment = characters(:ilker_hero).gain_item(name: "Sarı merhem", kind: "instant", hp: 5, uses: 0)

    assert_equal 1, ointment.uses_left, "uses must be at least 1 or the item arrives dead"
    assert_equal 5, ointment.hp_effect
  end

  test "a gained status is clamped to the dice range" do
    resolute = characters(:ilker_hero).gain_status(name: "Kararlı", modifier: 5, turns: 2)

    assert_equal 2, resolute.modifier, "narrator modifiers are clamped"
    assert_equal 2, resolute.turns_left
  end

  test "a status with no duration lasts two turns" do
    soaked = characters(:ilker_hero).gain_status(name: "Sırılsıklam", modifier: -1, turns: 0, expires_when: "")

    assert_equal 2, soaked.turns_left, "an open-ended status would never wear off"
    assert_nil soaked.expires_when
  end

  test "a regained status replaces its namesake instead of stacking" do
    character = characters(:ilker_hero)
    character.gain_status(name: "Sırılsıklam", modifier: -2, turns: 2)
    character.gain_status(name: "Sırılsıklam", modifier: -1, turns: 3)

    soaked = character.status_effects.where(name: "Sırılsıklam").sole
    assert_equal(-1, soaked.modifier)
    assert_equal 3, soaked.turns_left
  end

  test "losing takes carried items and statuses, never spent history" do
    character = characters(:ilker_hero)
    character.status_effects.create! name: "Yorgun", modifier: -1, expires_when: "dinlenene dek"
    items(:sifa_iksiri).use

    character.lose_item "Han defteri"
    character.lose_item "Şifa iksiri"
    character.lose_status "Yorgun"

    assert_not character.items.exists?(name: "Han defteri")
    assert character.items.exists?(name: "Şifa iksiri"), "a spent item is history, not inventory"
    assert_not character.status_effects.exists?(name: "Yorgun")
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
