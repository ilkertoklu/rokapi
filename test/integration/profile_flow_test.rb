require "test_helper"

class ProfileFlowTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:ilker)
  end

  test "the badge on home opens the profile instead of signing out" do
    get root_path

    assert_select "a.profile__badge[href=?]", my_profile_path, text: "I"
    assert_select "form[action=?]", session_path, count: 0
  end

  test "the profile shows who is signed in and the current language" do
    get my_profile_path

    assert_select ".page-head h1", text: "Profile"
    assert_select ".identity__name", text: "Ilker"
    assert_select ".identity__email", text: "ilker@example.com"
    assert_select ".segment[aria-current=true]", text: "English"
    assert_select ".segment[aria-current=false]", text: "Türkçe"
  end

  test "the language is changed from the profile" do
    get my_profile_path
    patch locale_path, params: { locale: "tr" }, headers: { "HTTP_REFERER" => my_profile_url }
    assert_redirected_to my_profile_url

    follow_redirect!
    assert_select "html[lang=tr]"
    assert_select ".page-head h1", text: "Profil"
    assert_select ".segment[aria-current=true]", text: "Türkçe"
  end

  test "signing out from the profile" do
    get my_profile_path
    assert_select "form[action=?] button", session_path, text: "Sign out"

    delete session_path
    assert_redirected_to welcome_path

    get my_profile_path
    assert_redirected_to welcome_path
  end
end
