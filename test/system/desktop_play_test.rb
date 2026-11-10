require "application_system_test_case"

class DesktopPlayTest < ApplicationSystemTestCase
  setup do
    @game_session = game_sessions(:ilker_solo)
    @game_session.update! started_at: Time.current
    @scene = @game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host), state: :choosing,
      title: "The Old Inn", location: "Whitebend", narration: "Rain hammers the inn's shutters."
    @scene.choices.create! label: "Force the cellar door", stat: "strength", modifier: 3, target: 12
    @scene.choices.create! label: "Listen at the door", stat: "wisdom", target: 10
  end

  teardown do
    page.current_window.resize_to 430, 932
  end

  test "choosing from the keyboard with the sheet beside the story" do
    sign_in_as users(:ilker)
    page.current_window.resize_to 1280, 800
    visit game_session_path(@game_session)

    assert_selector ".sheet", text: "Abilities"
    assert_button "Listen at the door"
    assert_no_button "My character"
    assert_selector ".topbar", visible: :hidden

    send_keys "2"
    assert_selector ".dice__prompt", text: "Listen at the door"
    assert_button "Roll the die"
  end

  test "a long scene points down to the choices waiting below it" do
    @scene.update! narration: Array.new(20, "Rain hammers the inn's shutters while the cellar door groans below.").join("\n\n")
    sign_in_as users(:ilker)
    page.current_window.resize_to 1440, 900
    visit game_session_path(@game_session)

    assert_button "Listen at the door", obscured: true
    assert_link "Your turn", obscured: false

    click_on "Your turn"
    assert_button "Listen at the door", obscured: false
    assert_link "Your turn", obscured: true
  end

  test "reading a new scene from the keyboard before the choices" do
    @scene.update! narration: Array.new(30, "Rain hammers the inn's shutters and the fire gutters low.").join("\n\n")
    sign_in_as users(:ilker)
    page.current_window.resize_to 1440, 900
    visit game_session_path(@game_session)

    assert_selector ".choice", text: "Force the cellar door", obscured: true
    send_keys :space
    first_page = assert_story_scrolled_past 0
    send_keys :page_down
    assert_story_scrolled_past first_page
    assert_no_selector ".choice:focus"

    send_keys :tab
    assert_selector ".choice:focus", text: "Force the cellar door"
  end

  test "menus sit in a panel under the top bar" do
    sign_in_as users(:ilker)
    page.current_window.resize_to 1280, 800
    visit new_game_sessions_solo_path

    assert_link "Rokapi", href: root_path
    assert_selector ".fate-card", count: 4
    assert_no_selector ".hand__dots"
    find(".fate-card", text: "Surprise").click
    assert_selector ".fate-card--face-down:has(:checked)"
  end

  test "the profile shows the subscription beside the account" do
    sign_in_as users(:ilker)
    visit my_profile_path
    assert_link "My subscription"
    assert_no_link "Upgrade your plan"

    page.current_window.resize_to 1280, 800
    assert_no_link "My subscription"
    assert_selector ".usage"
    assert_link "Upgrade your plan", href: subscriptions_paywall_path
  end

  private
    def assert_story_scrolled_past(offset)
      page.document.synchronize do
        evaluate_script("document.querySelector('.stage').scrollTop").tap do |scrolled|
          raise Capybara::ExpectationNotMet, "The story sits at #{scrolled}px" if scrolled <= offset
        end
      end
    end
end
