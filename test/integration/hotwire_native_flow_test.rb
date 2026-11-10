require "test_helper"

class HotwireNativeFlowTest < ActionDispatch::IntegrationTest
  IOS = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Hotwire Native iOS; Turbo Native iOS; bridge-components: []"
  ANDROID = "Mozilla/5.0 (Linux; Android 15; sdk_gphone64_arm64; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/124.0.6367.219 Mobile Safari/537.36 Hotwire Native Android; Turbo Native Android; bridge-components: []"

  test "both apps load one path configuration without signing in" do
    get hotwire_native_path_configuration_path(format: :json)

    assert_response :success
    assert_equal JSON.parse(Rails.root.join("config/path_configuration.json").read), response.parsed_body
    assert_no_match "max-age=31536000", response.headers["Cache-Control"].to_s
  end

  test "the apps bring their own navigation instead of the top bar" do
    get welcome_path
    assert_select ".topbar a", text: "Rokapi"

    get welcome_path, headers: { "User-Agent" => IOS }
    assert_select ".topbar", count: 0
  end

  test "setup screens open as modals and the home screen clears the stack" do
    get hotwire_native_path_configuration_path(format: :json)
    rules = response.parsed_body["rules"]

    assert_equal "hotwire://fragment/web", properties_for(rules, "/game_sessions/7")["uri"]
    assert_equal "default", properties_for(rules, "/game_sessions/7")["context"]
    assert_equal "modal", properties_for(rules, "/game_sessions/solo/new")["context"]
    assert_equal "modal", properties_for(rules, "/game_sessions/7/character/new")["context"]
    assert_equal "modal", properties_for(rules, "/session/new")["context"]
    assert_equal "clear_all", properties_for(rules, "/")["presentation"]
  end

  test "the game turns pull to refresh off so its panels can be dragged down" do
    get hotwire_native_path_configuration_path(format: :json)
    rules = response.parsed_body["rules"]

    assert_equal false, properties_for(rules, "/game_sessions/7")["pull_to_refresh_enabled"]
    assert_equal true, properties_for(rules, "/my/profile")["pull_to_refresh_enabled"]
    assert_equal false, properties_for(rules, "/game_sessions/7/character/new")["pull_to_refresh_enabled"]
  end

  test "the apps put the page title in the native bar and drop the web back control" do
    sign_in_as users(:sevval)

    [ IOS, ANDROID ].each do |user_agent|
      get new_game_session_path, headers: { "User-Agent" => user_agent }

      assert_response :success
      assert_select "title", text: "New adventure"
      assert_select "body.hotwire-native"
    end
  end

  test "the browser keeps the full title and the web back control" do
    sign_in_as users(:sevval)

    get new_game_session_path

    assert_select "title", text: "New adventure · Rokapi"
    assert_select "body.hotwire-native", count: 0
    assert_select ".page-head__back[href=?]", root_path

    get root_path
    assert_select "title", text: "Rokapi"
  end

  private
    def properties_for(rules, path)
      rules.select { |rule| rule["patterns"].any? { |pattern| path.match?(Regexp.new(pattern)) } }
        .map { |rule| rule["properties"] }.reduce({}, :merge)
    end
end
