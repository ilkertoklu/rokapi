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
