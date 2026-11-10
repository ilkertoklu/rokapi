require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "the host is the player who opened the room" do
    assert players(:ilker_room_host).host?
    assert_not players(:deniz_room_guest).host?
  end
end
