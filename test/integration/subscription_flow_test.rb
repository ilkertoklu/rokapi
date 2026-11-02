require "test_helper"

class SubscriptionFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  IOS = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Hotwire Native iOS; Turbo Native iOS; bridge-components: [paywall]"

  setup do
    @user = users(:sevval)
    sign_in_as @user
  end

  test "the profile leads to the subscription, which offers an upgrade on the free plan" do
    get my_profile_path
    assert_select "a.menu-row[href=?]", subscription_path, text: /My subscription/

    get subscription_path
    assert_select ".subscription__name", text: "Free"
    assert_select ".usage__left", text: "100% left"
    assert_select "a.btn--primary[href=?]", subscriptions_paywall_path, text: "Upgrade your plan"
    assert_select ".status-pill", count: 0
  end

  test "a subscriber manages the plan in the store" do
    subscribe @user, "premium", period: Time.zone.local(2026, 7, 3)...Time.zone.local(2026, 8, 3)

    travel_to Time.zone.local(2026, 7, 10) do
      get subscription_path
    end
    assert_select ".subscription__name", text: "Premium"
    assert_select ".subscription__terms", text: "Monthly · August 3"
    assert_select ".status-pill", text: "Active"
    assert_select "a.menu-row[href=?]", "https://apps.apple.com/account/subscriptions", text: /Change plan/
    assert_select "a[href=?]", "https://apps.apple.com/account/subscriptions", text: "Cancel subscription"

    get subscription_path(format: :json)
    assert_equal [ "premium", "active" ], response.parsed_body.values_at("plan", "status")
  end

  test "a cancelled subscription shows when it ends" do
    subscribe @user, "standard", status: "canceled", period: 1.week.ago...3.weeks.from_now

    get subscription_path
    assert_select ".status-pill--ending", text: "Ending"
    assert_select "a", text: "Cancel subscription", count: 0
    assert_select ".note", text: /then you move to the free plan/
  end

  test "the web explains that plans are bought in the app" do
    get subscriptions_paywall_path

    assert_select ".plan-option", count: 3
    assert_select ".plan-option__flag", text: "Most popular"
    assert_select ".plan-option__badge", count: 0
    assert_select "form", count: 0
    assert_select ".note", text: /bought in the Rokapi app/
  end

  test "the app's paywall sells each plan through the store" do
    subscribe @user, "standard"

    get subscriptions_paywall_path, headers: { "User-Agent" => IOS }

    assert_select "form#purchasekit_paywall[data-controller=?]", "purchasekit--paywall" do
      assert_select "input[type=radio][data-apple-store-product-id=?]", "app.rokapi.premium.monthly"
      assert_select "input[type=radio][checked][value=?]", "premium"
      assert_select "input[type=radio][checked]", count: 1
      assert_select "input[name=success_path][value=?]", subscriptions_welcome_path
      assert_select "input[type=submit][value=?][disabled]", "Subscribe"
    end
    assert_select ".plan-option", text: /Standard/ do
      assert_select ".plan-option__badge", text: "Current"
    end
    assert_select "turbo-cable-stream-source", count: 1
  end

  test "a demo purchase lands on the welcome with the new plan" do
    get subscriptions_paywall_path(format: :json)
    paywall = response.parsed_body
    premium = paywall["plans"].find { it["key"] == "premium" }

    post "/purchasekit/purchases.json", params: { product_id: premium["product_id"], customer_id: paywall["customer_id"], success_path: paywall["success_path"] }
    intent = response.parsed_body

    perform_enqueued_jobs { post "/purchasekit/purchase/completions/#{intent["uuid"]}" }
    assert_redirected_to "/subscriptions/welcome"

    follow_redirect!
    assert_select "h1", text: "You're on Premium"
    assert_select ".receipt__plan", text: "Premium"
    assert_equal Plan.fetch("premium"), @user.monthly_plan
  end

  test "the welcome waits for the store before the subscription exists" do
    get subscriptions_welcome_path

    assert_select "h1", text: "Confirming your purchase"
    assert_select "turbo-cable-stream-source"
  end

  test "restoring confirms an active subscription or says there is none" do
    post subscriptions_restoration_path, as: :json
    assert_redirected_to subscription_path
    assert_equal "No active subscription was found on this account.", flash[:alert]

    subscribe @user, "max"
    post subscriptions_restoration_path, as: :json
    assert_equal "Your subscription is active on this account.", flash[:notice]
  end

  test "the usage wall offers the plans" do
    subscribe @user, "standard", status: "expired"
    Plan.free.scenes.times { |index| create_scene_for @user, index }

    get new_game_sessions_solo_path
    assert_select "a.btn--primary[href=?]", subscriptions_paywall_path, text: "Upgrade your plan"
  end

  test "deleting the account warns about the store subscription and leaves no billing records" do
    subscribe @user, "premium"

    get my_account_path
    assert_select ".note", text: /cancel it in the App Store or Google Play/

    delete my_account_path, params: { confirmation: "DELETE" }
    assert_redirected_to welcome_path
    assert_empty Pay::Customer.where(owner_type: "User", owner_id: @user.id)
    assert_empty Pay::Subscription.all
  end

  private
    def create_scene_for(user, index)
      game_session = user.created_game_sessions.first || GameSession.create!(creator: user, quest: "lost_caravan")
      game_session.scenes.create! position: index + 1, active_player: game_session.host
    end
end
