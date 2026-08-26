require "test_helper"

class StatusEffectTest < ActiveSupport::TestCase
  setup do
    @character = characters(:ilker_hero)
  end

  test "a timed status counts down and expires" do
    status = @character.status_effects.create! name: "Kararlı", modifier: 1, turns_left: 2

    status.tick!
    assert_equal 1, status.reload.turns_left

    status.tick!
    assert_not StatusEffect.exists?(status.id)
  end

  test "a conditional status outlives the countdown" do
    status = @character.status_effects.create! name: "Sırılsıklam", modifier: -2, expires_when: "kuruyana dek"

    status.tick!

    assert StatusEffect.exists?(status.id)
    assert_equal "kuruyana dek", status.duration_label
  end

  test "statuses sum into the character's dice modifier" do
    @character.status_effects.create! name: "Kararlı", modifier: 1, turns_left: 2
    @character.status_effects.create! name: "Yorgun", modifier: -2, expires_when: "dinlenene dek"

    assert_equal(-1, @character.status_modifier)
  end
end
