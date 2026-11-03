require "test_helper"

class AccountDeletionFlowTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:ilker)
  end

  test "deletion opens from settings behind a typed confirmation" do
    get my_settings_path
    assert_select "a.menu-row--danger[href=?]", my_account_path, text: /Delete my account/

    get my_account_path
    assert_select ".warning h2", text: "This cannot be undone"
    assert_select "form[data-controller=confirmation][data-confirmation-word-value=DELETE]"
    assert_select "input[type=submit][value=?]", "Delete my account for good"
  end

  test "the account stays without the confirmation word" do
    [ nil, "", "delet", "YES" ].each do |confirmation|
      delete my_account_path, params: { confirmation: confirmation }
      assert_redirected_to my_account_path
      assert_match(/Type “DELETE”/, flash[:alert])
    end

    assert User.exists?(users(:ilker).id)
  end

  test "the Turkish word is accepted however it is typed" do
    [ "SİL", "sil", "SIL", " Sil " ].each do |confirmation|
      user = User.create!(email: "#{SecureRandom.hex(4)}@rokapi.test", name: "Sena", terms_accepted_at: Time.current)
      sign_in_as user

      delete my_account_path, params: { confirmation: confirmation }, headers: { "Accept-Language" => "tr" }
      assert_redirected_to welcome_path, "#{confirmation.inspect} was refused"
      assert_not User.exists?(user.id)
    end
  end

  test "deleting removes the user with sessions, characters and stories and signs out" do
    ilker = users(:ilker)
    hero = characters(:ilker_hero)
    hosted = game_sessions(:ilker_solo)
    hosted.players.create!(user: users(:deniz))
    hosted.scenes.create! position: 1, active_player: players(:ilker_solo_host), state: :choosing, title: "The Old Inn"

    delete my_account_path, params: { confirmation: "delete" }
    assert_redirected_to welcome_path

    assert_not User.exists?(ilker.id)
    assert_empty Session.where(user_id: ilker.id)
    assert_empty GameSession.where(creator_id: ilker.id)
    assert_empty Player.where(game_session_id: hosted.id)
    assert_empty Scene.where(game_session_id: hosted.id)
    assert_not Character.exists?(hero.id)

    assert User.exists?(users(:deniz).id)
    assert GameSession.exists?(game_sessions(:deniz_solo).id)

    get my_profile_path
    assert_redirected_to welcome_path
  end

  test "a deleted email can sign up again" do
    delete my_account_path, params: { confirmation: "DELETE" }

    post login_codes_path, params: { email: "ilker@example.com" }
    post session_path, params: { code: LoginCode.last.code }
    follow_redirect!
    assert_redirected_to new_signup_profile_path

    user = User.find_by!(email: "ilker@example.com")
    assert_not_equal users(:ilker).id, user.id
    assert_empty user.game_sessions
  end

  test "deleting as JSON" do
    delete my_account_path(format: :json), params: { confirmation: "nope" }, as: :json
    assert_response :unprocessable_entity
    assert_equal "Type “DELETE” to delete your account.", response.parsed_body["confirmation"]

    delete my_account_path(format: :json), params: { confirmation: "DELETE" }, as: :json
    assert_response :no_content
    assert_not User.exists?(users(:ilker).id)
  end
end
