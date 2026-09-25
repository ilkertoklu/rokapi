require "test_helper"

class LocalizationFlowTest < ActionDispatch::IntegrationTest
  test "visitors are greeted in the language their browser asks for" do
    get welcome_path, headers: { "Accept-Language" => "tr-TR,tr;q=0.9,en;q=0.8" }

    assert_select "html[lang=tr]"
    assert_select ".btn", text: "Hesap oluştur"
  end

  test "an unsupported browser language falls back to English" do
    get welcome_path, headers: { "Accept-Language" => "de-DE,de;q=0.9" }

    assert_select "html[lang=en]"
    assert_select ".btn", text: "Create account"
  end

  test "the language switch outweighs the browser" do
    patch locale_path, params: { locale: "tr" }, headers: { "HTTP_REFERER" => welcome_url }
    assert_redirected_to welcome_url

    get welcome_path, headers: { "Accept-Language" => "en-US,en" }
    assert_select "html[lang=tr]"
    assert_select ".locales__option[disabled]", text: "Türkçe"
  end

  test "an unknown language is ignored" do
    patch locale_path, params: { locale: "xx" }

    get welcome_path
    assert_select "html[lang=en]"
  end

  test "the sign-in code is mailed in the visitor's language" do
    patch locale_path, params: { locale: "tr" }

    perform_enqueued_jobs do
      post login_codes_path, params: { email: users(:ilker).email }
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal "Rokapi kodun: #{users(:ilker).login_codes.sole.code}", email.subject
    assert_match "Merhaba", email.text_part.body.to_s
  end

  test "flash messages follow the language" do
    patch locale_path, params: { locale: "tr" }

    post login_codes_path, params: { email: "gecersiz" }
    assert_equal "Geçerli bir e-posta adresi gir.", flash[:alert]
  end

  test "an adventure set up in Turkish is played in Turkish" do
    sign_in_as users(:sevval)
    patch locale_path, params: { locale: "tr" }

    get new_game_sessions_solo_path
    assert_select ".pick__title", text: "Kayıp Kervan"
    assert_select ".segment span", text: "Karanlık"

    post game_sessions_solo_path, params: { game_session: { quest: "lost_caravan", tone: "dark", length: "short" } }
    game_session = users(:sevval).game_sessions.sole
    assert_equal "tr", game_session.locale

    follow_redirect!
    assert_select ".page-head h1", text: "Karakterini oluştur"
    assert_select ".chip span", text: "Savaşçı"
    assert_select ".stat-row__label", text: "Güç"
    assert_select "[data-stats-ready-value=?]", "Hazırım"
  end

  test "switching the page language leaves a running adventure in its own language" do
    sign_in_as users(:ilker)

    patch locale_path, params: { locale: "tr" }

    assert_equal "en", game_sessions(:ilker_solo).reload.locale
  end
end
