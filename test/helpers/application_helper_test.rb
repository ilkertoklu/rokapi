require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "lowercase keeps the Turkish dotted and dotless i apart" do
    I18n.with_locale(:tr) { assert_equal "ılık irmik", lowercase("ILIK İRMİK") }
    assert_equal "intelligence", lowercase("Intelligence")
  end
end
