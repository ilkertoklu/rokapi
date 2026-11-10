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

  test "the choices rise under the cue instead of drawing a second edge" do
    @scene.update! narration: Array.new(20, "Rain hammers the inn's shutters while the cellar door groans below.").join("\n\n")
    sign_in_as users(:ilker)
    page.current_window.resize_to 1440, 900
    visit game_session_path(@game_session)

    execute_script <<~JS
      const stage = document.querySelector(".stage")
      stage.scrollTop += document.querySelector(".action-panel").getBoundingClientRect().top - stage.getBoundingClientRect().bottom + 40
    JS
    assert_link "Your turn", obscured: false
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

  test "playing a turn with Tab and Enter only" do
    sign_in_as users(:ilker)
    page.current_window.resize_to 1280, 800
    visit game_session_path(@game_session)

    send_keys :tab
    assert_selector ".choice:focus", text: "Force the cellar door"
    send_keys :enter
    assert_selector ".dice__prompt", text: "Force the cellar door"

    send_keys :tab
    assert_selector "button:focus", text: "Roll the die"
    send_keys :enter
    assert_text "The narrator is resolving the roll"

    @scene.reload.roll.resolve resolution: "The door gives way.", effects: {}
    assert_text "The door gives way."
    send_keys :tab
    assert_selector "button:focus", text: "Continue"
    send_keys :enter
    assert_no_text "The door gives way."

    next_scene = @game_session.scenes.last
    next_scene.choices.create! label: "Climb down to the cellar", stat: "agility", target: 10
    next_scene.update! state: :choosing, title: "The Cellar", narration: "Cold air rises from below."
    assert_text "Cold air rises from below."
    send_keys :tab
    assert_selector ".choice:focus", text: "Climb down to the cellar"
  end

  test "starting an adventure from the keyboard" do
    sign_in_as users(:ilker)
    page.current_window.resize_to 1440, 900

    tab_to "a", text: "Start a new adventure"
    send_keys :enter
    tab_to "a", text: "Solo"
    send_keys :enter

    tab_to ".fate-card input"
    send_keys :right
    assert_selector ".fate-card:nth-child(2) input:focus:checked", visible: :all
    assert_selector "button[aria-keyshortcuts=Enter]", text: "Create your character"
    send_keys :enter

    tab_to ".chip input[value=warrior]"
    send_keys :right
    assert_selector ".chip input[value=ranger]:focus:checked", visible: :all
    tab_to "button[aria-label='Raise Agility']"
    4.times { send_keys :enter }
    tab_to "button[aria-label='Raise Wisdom']"
    2.times { send_keys :enter }
    assert_selector "button[aria-keyshortcuts=Enter]:not(:disabled)", text: "I'm ready"
    press :enter
    assert_text "The narrator is getting ready"

    game_session = users(:ilker).game_sessions.order(:id).last
    assert_equal "ranger", game_session.players.sole.character.klass
    scene = game_session.scenes.sole
    scene.choices.create! label: "Slip past the harbour guards", stat: "agility", target: 10
    scene.update! state: :choosing, title: "The Docks", narration: "Gulls wheel over the harbour."
    assert_text "Gulls wheel over the harbour."

    send_keys "1"
    assert_selector ".dice__prompt", text: "Slip past the harbour guards"
    send_keys :enter
    assert_text "The narrator is resolving the roll"

    scene.reload.roll.resolve resolution: "The guards never look up.", effects: {}
    assert_text "The guards never look up."
    send_keys :enter
    assert_no_text "The guards never look up."

    next_scene = game_session.scenes.last
    next_scene.choices.create! label: "Board the smuggler's boat", stat: "agility", target: 10
    next_scene.update! state: :choosing, title: "The Pier", narration: "A lantern swings at the end of the pier."
    assert_text "A lantern swings at the end of the pier."
  end

  test "Enter readies the character from the stepper that spent the last point" do
    sign_in_as users(:ilker)
    page.current_window.resize_to 1440, 900
    visit new_game_sessions_solo_path
    click_on "Create your character"

    choose "Ranger", allow_label_click: true
    4.times { click_on "Raise Agility" }
    click_on "Raise Wisdom"
    execute_script <<~JS
      const stepper = document.querySelector("button[aria-label='Raise Wisdom']")
      stepper.focus()
      stepper.click()
      stepper.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true }))
    JS
    assert_text "The narrator is getting ready"
  end

  test "a step leaves the focus where the player moved it" do
    @scene.choices.first.choose
    @scene.roll_dice by: players(:ilker_solo_host)
    sign_in_as users(:ilker)
    page.current_window.resize_to 1280, 800
    visit game_session_path(@game_session)

    send_keys :tab
    assert_selector ".sheet button:focus", text: "Use"
    @scene.roll.resolve resolution: "The door gives way.", effects: {}
    assert_text "The door gives way."
    assert_selector ".sheet button:focus", text: "Use"
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
