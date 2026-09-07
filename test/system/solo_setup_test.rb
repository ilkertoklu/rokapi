require "application_system_test_case"

class SoloSetupTest < ApplicationSystemTestCase
  test "logging in and spending the character's free points" do
    visit new_login_code_path
    fill_in "E-posta", with: users(:sevval).email
    click_on "Kod gönder"
    assert_text "adresine gönderdik"

    fill_in "code", with: LoginCode.last.code
    click_on "Doğrula"
    assert_text "Zarları at"

    click_on "Yeni macera kur"
    click_on "Tek kişilik"
    click_on "Karakterini oluştur"

    choose "Büyücü", allow_label_click: true
    assert_field "character[stats][intelligence]", with: "15"
    assert_button "Hazırım · 6 puan kaldı", disabled: true

    3.times { increment "intelligence" }
    3.times { increment "wisdom" }
    assert_field "character[stats][intelligence]", with: "18"
    assert_field "character[stats][wisdom]", with: "17"

    click_on "Hazırım"
    assert_text "Anlatıcı hazırlanıyor"

    character = users(:sevval).game_sessions.sole.player_for(users(:sevval)).character
    assert_equal "mage", character.klass
    assert_equal 18, character.stats["intelligence"]
  end

  private
    def increment(stat)
      find("button[data-action='stats#increment'][data-stats-key-param='#{stat}']").click
    end
end
