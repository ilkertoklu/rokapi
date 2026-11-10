require "test_helper"

class LoginFlowTest < ActionDispatch::IntegrationTest
  test "logging in with a one-time code" do
    post login_codes_path, params: { email: users(:ilker).email }
    assert_redirected_to new_session_path

    get new_session_path
    assert_select "input[name=code][aria-label=?]", "Login code"

    post session_path, params: { code: LoginCode.last.code }
    assert_redirected_to root_url

    get root_path
    assert_response :success
  end

  test "the code stays out of the logs" do
    post login_codes_path, params: { email: users(:ilker).email }
    post session_path, params: { code: LoginCode.last.code }

    assert_equal "[FILTERED]", request.filtered_parameters["code"]
  end

  test "wrong code keeps the user on the code page" do
    post login_codes_path, params: { email: users(:ilker).email }

    post session_path, params: { code: "000000" }
    assert_redirected_to new_session_path
    assert_match(/That code is wrong/, flash[:alert])
  end

  test "a code spent on wrong tries points to a new code" do
    post login_codes_path, params: { email: users(:ilker).email }
    code = LoginCode.last.code

    LoginCode::MAX_ATTEMPTS.times { post session_path, params: { code: "000000" } }
    post session_path, params: { code: code }

    assert_redirected_to new_session_path
    assert_equal "That code is wrong or has expired. Try again or send a new code.", flash[:alert]

    get root_path
    assert_redirected_to welcome_path
  end

  test "friends on one network all get their codes" do
    counting_rate_limits do
      6.times do |friend|
        post login_codes_path, params: { email: "friend#{friend}@example.com" }
        assert_redirected_to new_session_path
      end
    end

    assert_equal 6, LoginCode.joins(:user).where("users.email LIKE 'friend%'").count
  end

  test "one address gets five codes within three minutes" do
    counting_rate_limits do
      5.times do
        post login_codes_path, params: { email: " Ilker@Example.com " }
        assert_redirected_to new_session_path
      end

      assert_no_difference -> { LoginCode.count } do
        post login_codes_path, params: { email: users(:ilker).email }
      end
      assert_redirected_to new_login_code_path
      assert_match(/Too many attempts/, flash[:alert])
    end
  end

  test "code page without a pending email goes back to login" do
    get new_session_path
    assert_redirected_to new_login_code_path
  end

  test "resend invalidates the previous code" do
    post login_codes_path, params: { email: users(:ilker).email }
    stale_code = LoginCode.last.code

    post login_codes_resend_path
    assert_redirected_to new_session_path
    fresh_code = LoginCode.last.code

    post session_path, params: { code: stale_code }
    assert_redirected_to new_session_path

    post session_path, params: { code: fresh_code }
    assert_redirected_to root_url
  end

  test "friends on one network each get their own resends" do
    counting_rate_limits do
      post login_codes_path, params: { email: users(:ilker).email }
      3.times do
        post login_codes_resend_path
        assert_equal "A new code is on its way.", flash[:notice]
      end

      post login_codes_resend_path
      assert_match(/Too many code requests/, flash[:alert])

      post login_codes_path, params: { email: users(:deniz).email }
      post login_codes_resend_path
      assert_equal "A new code is on its way.", flash[:notice]
    end
  end

  test "logging out" do
    sign_in_as users(:ilker)

    delete session_path
    assert_redirected_to welcome_path

    get root_path
    assert_redirected_to welcome_path
  end

  test "unauthenticated visitors land on the welcome screen" do
    get root_path
    assert_redirected_to welcome_path
  end

  test "authenticated users skip the auth screens" do
    sign_in_as users(:ilker)

    get welcome_path
    assert_redirected_to root_url

    get new_login_code_path
    assert_redirected_to root_url
  end
end
