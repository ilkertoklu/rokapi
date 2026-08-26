require "test_helper"

class ItemTest < ActiveSupport::TestCase
  setup do
    @potion = items(:sifa_iksiri)
    @character = @potion.character
  end

  test "using a potion heals up to max hp and spends a use" do
    @character.update! hp: 20

    @potion.use!

    assert_equal 27, @character.reload.hp
    assert_equal 0, @potion.uses_left
    assert @potion.used_at.present?
  end

  test "healing never exceeds max hp" do
    @potion.use!

    assert_equal @character.max_hp, @character.reload.hp
  end

  test "a spent or passive item cannot be used" do
    @potion.update! uses_left: 0

    assert_raises(Item::Unusable) { @potion.use! }
    assert_raises(Item::Unusable) { items(:uzun_kilic).use! }
  end

  test "a stale copy cannot double-spend the last use" do
    @character.update! hp: 10
    stale = Item.find(@potion.id)

    @potion.use!

    assert_raises(Item::Unusable) { stale.use! }
    assert_equal 0, stale.reload.uses_left
    assert_equal 17, @character.reload.hp
  end

  test "descriptions are capitalized the Turkish way" do
    item = @character.items.create! name: "Merhem", kind: "passive", description: "iyileştirir"

    assert_equal "İyileştirir", item.description
  end

  test "spent items drop out of the carried inventory but stay on record" do
    @potion.use!

    assert_not_includes @character.items.carried, @potion
    assert_includes @character.items, @potion
    assert_includes @character.items.carried, items(:uzun_kilic)
  end

  test "healing covers only carried items that restore hp" do
    assert_includes @character.items.healing, @potion
    assert_not_includes @character.items.healing, items(:uzun_kilic)

    @potion.use!
    assert_empty @character.items.healing
  end

  test "summary speaks the narrator's language" do
    assert_equal "Şifa iksiri (anında: +7 can, 1 hak)", @potion.summary
    assert_equal "Uzun kılıç", items(:uzun_kilic).summary
    assert_equal "Han defteri (görev eşyası)", items(:han_defteri).summary
  end
end
