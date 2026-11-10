require "test_helper"

class SignupFlowTest < ActionDispatch::IntegrationTest
  test "signing up: email, code, profile, welcome" do
    post login_codes_path, params: { email: "taze@posta.com" }
    assert_redirected_to new_session_path

    user = User.find_by!(email: "taze@posta.com")
    post session_path, params: { code: LoginCode.last.code }
    assert_redirected_to root_url

    follow_redirect!
    assert_redirected_to new_signup_profile_path

    post signup_profile_path, params: { user: { name: "Robin", terms: "1" } }
    assert_redirected_to signup_welcome_path

    follow_redirect!
    assert_response :success
    assert_select "h1", text: /Welcome, Robin/

    get root_path
    assert_response :success
    assert user.reload.profile_complete?
  end

  test "a game link that sent a new player to log in is gone by the next login" do
    get game_session_path(game_sessions(:ilker_room))
    assert_redirected_to welcome_path

    post login_codes_path, params: { email: "taze@posta.com" }
    post session_path, params: { code: LoginCode.last.code }
    assert_redirected_to game_session_url(game_sessions(:ilker_room))

    follow_redirect!
    assert_redirected_to new_signup_profile_path
    post signup_profile_path, params: { name: "Robin", terms: "1" }
    delete session_path

    post login_codes_path, params: { email: "taze@posta.com" }
    post session_path, params: { code: LoginCode.last.code }
    assert_redirected_to root_url
  end

  test "profile completion requires accepting the terms" do
    sign_in_as users(:incomplete)

    post signup_profile_path, params: { user: { name: "Robin", terms: "0" } }
    assert_redirected_to new_signup_profile_path
    assert_equal "You need to accept the terms to continue.", flash[:alert]
    assert_not users(:incomplete).reload.profile_complete?
  end

  test "profile completion requires a name" do
    sign_in_as users(:incomplete)

    post signup_profile_path, params: { user: { name: "   ", terms: "1" } }
    assert_redirected_to new_signup_profile_path
    assert_equal "You need to enter your name to continue.", flash[:alert]
    assert_not users(:incomplete).reload.profile_complete?
  end

  test "resubmitting the profile keeps the original terms acceptance" do
    user = users(:ilker)
    sign_in_as user

    assert_no_changes -> { user.reload.terms_accepted_at } do
      post signup_profile_path, params: { user: { name: "Ilker", terms: "1" } }
    end
  end

  test "the profile form posts the name and terms as the user's" do
    sign_in_as users(:incomplete)

    get new_signup_profile_path

    assert_select "form[action=?][method=post]", signup_profile_path do
      assert_select "input[name=_method]", count: 0
      assert_select "input[name=?]", "user[name]"
      assert_select "input[type=checkbox][name=?]", "user[terms]"
    end
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
    assert_equal "Enter a valid email address.", flash[:alert]

    post login_codes_path, params: { email: "gecersiz" }
    assert_redirected_to new_login_code_path
  end
end
