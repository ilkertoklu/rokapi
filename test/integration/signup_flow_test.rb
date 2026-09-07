require "test_helper"

class SignupFlowTest < ActionDispatch::IntegrationTest
  test "signing up: email, code, profile, welcome" do
    post login_codes_path, params: { email: "taze@posta.com" }
    assert_redirected_to new_session_path

    user = User.find_by!(email: "taze@posta.com")
    post session_path, params: { code: LoginCode.last.code }
    assert_redirected_to new_signup_profile_path

    post signup_profile_path, params: { name: "Taze", terms: "1" }
    assert_redirected_to signup_welcome_path

    follow_redirect!
    assert_response :success
    assert_select "h1", text: /Hoş geldin, Taze/

    get root_path
    assert_response :success
    assert user.reload.profile_complete?
  end

  test "profile completion requires accepting the terms" do
    sign_in_as users(:incomplete)

    post signup_profile_path, params: { name: "Yeni", terms: "0" }
    assert_redirected_to new_signup_profile_path
    assert_not users(:incomplete).reload.profile_complete?
  end

  test "incomplete users are pushed to profile completion everywhere" do
    sign_in_as users(:incomplete)

    get root_path
    assert_redirected_to new_signup_profile_path
  end

  test "the signup screen sends its form through the login flow" do
    get new_signup_path

    assert_select "form[action=?]", login_codes_path
    assert_select "a[href=?]", new_login_code_path
  end

  test "invalid email returns to the screen it was typed on" do
    post login_codes_path, params: { email: "gecersiz" }, headers: { "HTTP_REFERER" => new_signup_url }
    assert_redirected_to new_signup_path
    assert_equal "Geçerli bir e-posta adresi gir.", flash[:alert]

    post login_codes_path, params: { email: "gecersiz" }
    assert_redirected_to new_login_code_path
  end
end
