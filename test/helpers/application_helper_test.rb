require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "signed numbers always carry their sign" do
    assert_equal [ "+2", "+0", "-1" ], [ 2, 0, -1 ].map { signed_number it }
  end

  test "lowercase keeps the Turkish dotted and dotless i apart" do
    I18n.with_locale(:tr) { assert_equal "ılık irmik", lowercase("ILIK İRMİK") }
    assert_equal "intelligence", lowercase("Intelligence")
  end
end
