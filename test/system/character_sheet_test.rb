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

  private
    def open_sheet_from_the_keyboard
      tab_to ".action-panel__handle"
      send_keys :enter
      tab_to ".character-button"
      send_keys :enter
      assert_selector ".sheet:modal .sheet__handle:focus"
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
