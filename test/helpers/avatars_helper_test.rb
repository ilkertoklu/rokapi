require "test_helper"

class AvatarsHelperTest < ActionView::TestCase
  test "an avatar on its own carries the name for screen readers" do
    render html: avatar_tag(users(:ilker))

    assert_select ".avatar[title=Ilker]:not([aria-hidden])" do
      assert_select "span[aria-hidden=true]", text: "I"
      assert_select ".visually-hidden", text: "Ilker"
    end
  end

  test "an avatar beside the name stays out of the screen reader" do
    render html: avatar_tag(users(:ilker), "avatar--ringed", hidden: true)

    assert_select ".avatar.avatar--ringed[aria-hidden=true]", text: "I"
    assert_select ".visually-hidden", count: 0
  end
end
