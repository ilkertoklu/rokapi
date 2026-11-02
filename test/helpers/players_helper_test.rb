require "test_helper"

class PlayersHelperTest < ActionView::TestCase
  test "genitive follows Turkish vowel harmony" do
    I18n.with_locale(:tr) do
      assert_equal "Şevval’in", genitive("Şevval")
      assert_equal "İlker’in", genitive("İlker")
      assert_equal "Sena’nın", genitive("Sena")
      assert_equal "Umut’un", genitive("Umut")
      assert_equal "Ülkü’nün", genitive("Ülkü")
      assert_equal "Ali’nin", genitive("Ali")
      assert_equal "Kemal’in", genitive("Kemal")
    end
  end

  test "genitive in English" do
    assert_equal "Deniz’s", genitive("Deniz")
  end
end
