require "test_helper"

class LoginFlowTest < ActionDispatch::IntegrationTest
  test "logging in with a one-time code" do
    post login_codes_path, params: { email: users(:ilker).email }
    assert_redirected_to new_session_path

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
    assert_match(/Kod hatalı/, flash[:alert])
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
