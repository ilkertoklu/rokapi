require "application_system_test_case"

class CharacterSheetTest < ApplicationSystemTestCase
  setup do
    @game_session = game_sessions(:ilker_solo)
    @game_session.update! started_at: Time.current
    @scene = @game_session.scenes.create! position: 1, active_player: players(:ilker_solo_host), state: :choosing,
      title: "The Old Inn", location: "Whitebend", narration: "Rain hammers the inn's shutters."
    @scene.choices.create! label: "Force the cellar door", stat: "strength", modifier: 3, target: 12

    sign_in_as users(:ilker)
    visit game_session_path(@game_session)
  end

  teardown do
    page.current_window.resize_to 430, 932
  end

  test "the sheet keeps the keyboard until Esc hands it back to My character" do
    open_sheet_from_the_keyboard

    6.times do
      send_keys :tab
      assert focus_stays_in_sheet?, "Tab left the sheet"
    end
    send_keys [ :shift, :tab ]
    assert focus_stays_in_sheet?, "Shift+Tab left the sheet"

    send_keys "1"
    assert_selector ".sheet:modal"
    assert @scene.reload.choosing?

    send_keys :escape
    assert_no_selector ".sheet:modal"
    assert_selector ".character-button:focus", text: "My character"
  end

  test "a refresh behind the open sheet leaves it open" do
    open_sheet_from_the_keyboard

    @scene.update! title: "The Old Inn at Dusk"
    assert_text "The Old Inn at Dusk"
    assert_selector ".sheet:modal .sheet__handle:focus"
  end

  test "using an item hands the focus to its result" do
    characters(:ilker_hero).update! hp: 20
    open_sheet_from_the_keyboard

    tab_to ".inventory__use"
    send_keys :enter
    assert_text "+7 Health"
    assert_no_selector ".sheet:modal"
    assert_selector ".stage:focus"
  end

  test "dragging the sheet down by its handle closes it" do
    open_sheet_by_tapping

    swipe ".sheet__handle", down: 400
    assert_no_selector ".sheet:modal"
    assert_selector ".character-button:focus"
  end

  test "dragging the panel down from the top of its contents closes the sheet" do
    open_sheet_by_tapping

    swipe ".sheet__header", down: 400
    assert_no_selector ".sheet:modal"
  end

  test "a short drag settles the sheet back open" do
    open_sheet_by_tapping

    swipe ".sheet__handle", down: 80, step_duration: 0.1
    assert_panels_at_rest
    assert_selector ".sheet:modal .sheet__handle:focus"
    assert_equal "", evaluate_script("document.querySelector('.sheet__panel').style.translate")
  end

  test "a tap on the handle or the scrim still closes the sheet" do
    open_sheet_by_tapping
    find(".sheet__handle").click
    assert_no_selector ".sheet:modal"

    open_sheet_by_tapping
    scrim = find(".sheet__scrim")
    scrim.click(x: 0, y: 20 - scrim.rect.height / 2)
    assert_no_selector ".sheet:modal"
  end

  test "a refresh in the middle of a drag leaves the sheet fully open or closed" do
    open_sheet_by_tapping

    drag_the_handle_through_a_refresh to: "The Old Inn at Dusk", down: 120
    assert_text "The Old Inn at Dusk"
    assert_panels_at_rest
    assert_selector ".sheet:modal"
    assert_equal "", evaluate_script("document.querySelector('.sheet__panel').style.translate")

    drag_the_handle_through_a_refresh to: "The Old Inn at Night", down: 400
    assert_text "The Old Inn at Night"
    assert_no_selector ".sheet:modal"
  end

  test "the sheet reads as a region beside the story and as a dialog over it" do
    name = characters(:ilker_hero).name
    page.current_window.resize_to 1440, 900
    assert_sheet_reads_as "region", name

    page.current_window.resize_to 430, 932
    open_sheet_by_tapping
    assert_sheet_reads_as "dialog", name

    find(".sheet__handle").click
    assert_no_selector ".sheet:modal"
    page.current_window.resize_to 1440, 900
    assert_sheet_reads_as "region", name
  end

  private
    def assert_sheet_reads_as(role, name)
      sheet = find(".sheet").native
      assert_equal [ role, name ], [ sheet.aria_role, sheet.accessible_name ]
    end

    def open_sheet_by_tapping
      find(".action-panel__handle").click unless has_button?("My character", wait: 0)
      click_on "My character"
      assert_selector ".sheet:modal"
      assert_panels_at_rest
    end

    def open_sheet_from_the_keyboard
      tab_to ".action-panel__handle"
      send_keys :enter
      tab_to ".character-button"
      send_keys :enter
      assert_selector ".sheet:modal .sheet__handle:focus"
    end

    def drag_the_handle_through_a_refresh(to:, down:)
      @scene.update_columns title: to
      execute_script "setTimeout(() => Turbo.session.refresh(location.href), 300)"

      action = page.driver.browser.action
      finger = action.add_pointer_input(:touch, "finger")
      action.move_to(find(".sheet__handle").native, device: "finger", duration: 0).pointer_down(device: "finger")
      action.move_by(0, 80, device: "finger", duration: 0.2).pause(device: finger, duration: 1)
      action.move_by(0, down - 80, device: "finger", duration: 0.2).pointer_up(device: "finger").perform
      action.release_actions
    end

    def tab_to(selector)
      page.document.synchronize do
        send_keys :tab
        raise Capybara::ExpectationNotMet, "Tabbed past #{selector}" unless has_selector?("#{selector}:focus", wait: 0)
      end
    end

    def focus_stays_in_sheet?
      evaluate_script "document.activeElement === document.body || !!document.activeElement.closest('.sheet:modal')"
    end
end
