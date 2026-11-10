require "test_helper"

class JobsDashboardFlowTest < ActionDispatch::IntegrationTest
  test "the jobs dashboard refuses anyone without the operator's credentials, signed-in players included" do
    get "/jobs"
    assert_response :unauthorized

    get "/jobs", headers: { "Authorization" => basic_auth("dev", "wrong") }
    assert_response :unauthorized

    sign_in_as users(:sevval)
    get "/jobs"
    assert_response :unauthorized
  end

  test "the jobs dashboard opens with the operator's credentials" do
    get "/jobs", headers: { "Authorization" => basic_auth("dev", "secret") }
    assert_response :success
    assert_select "title", /Queues/
  end

  private
    def basic_auth(name, password)
      ActionController::HttpAuthentication::Basic.encode_credentials(name, password)
    end
end
