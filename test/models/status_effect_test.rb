require "test_helper"

class StatusEffectTest < ActiveSupport::TestCase
  setup do
    @character = characters(:ilker_hero)
  end

  test "a timed status counts down and expires" do
    status = @character.status_effects.create! name: "Sure Grip", modifier: 1, turns_left: 2

    status.tick
    assert_equal 1, status.reload.turns_left

    status.tick
    assert_not StatusEffect.exists?(status.id)
  end

  test "a conditional status outlives the countdown" do
    status = @character.status_effects.create! name: "Soaked Through", modifier: -2, expires_when: "until it dries"

    status.tick

    assert StatusEffect.exists?(status.id)
    assert_equal "until it dries", status.duration_label
  end

  test "statuses sum into the character's dice modifier" do
    @character.status_effects.create! name: "Sure Grip", modifier: 1, turns_left: 2
    @character.status_effects.create! name: "Dragging Leg", modifier: -2, expires_when: "until it eases"

    assert_equal(-1, @character.status_modifier)
  end
end
