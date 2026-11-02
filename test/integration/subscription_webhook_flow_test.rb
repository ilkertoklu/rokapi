require "test_helper"

class SubscriptionWebhookFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  WEBHOOK_SECRET = "whsec_test"

  setup do
    @user = users(:sevval)
    @customer = @user.payment_processor
    @period = Time.zone.local(2026, 7, 3, 9)...Time.zone.local(2026, 8, 3, 9)
    PurchaseKit.config.webhook_secret = WEBHOOK_SECRET
  end

  teardown do
    PurchaseKit.config.webhook_secret = nil
  end

  test "a store subscription takes the user from free to Premium and back to free at the end of the period" do
    travel_to Time.zone.local(2026, 7, 3, 9) do
      assert_equal Plan.free, @user.monthly_plan

      deliver "subscription.created", status: "active"
      assert_equal Plan.fetch("premium"), @user.monthly_plan
      assert_equal 100, @user.usage_left_percentage
      assert_equal @period.end, @user.usage_refills_at
    end

    travel_to Time.zone.local(2026, 7, 20) do
      deliver "subscription.canceled", status: "canceled"
      assert_equal "canceled", @user.pay_subscriptions.sole.status
      assert_equal Plan.fetch("premium"), @user.monthly_plan, "a cancelled subscription runs to the end of its period"
    end

    travel_to Time.zone.local(2026, 8, 3, 9, 1) do
      assert_equal Plan.free, @user.monthly_plan

      deliver "subscription.expired", status: "expired"
      assert_equal Plan.free, @user.monthly_plan
    end
  end

  test "a renewal moves the usage period forward" do
    travel_to Time.zone.local(2026, 7, 3, 9) { deliver "subscription.created", status: "active" }

    travel_to Time.zone.local(2026, 8, 3, 9, 1) do
      deliver "subscription.updated", status: "active", period: Time.zone.local(2026, 8, 3, 9)...Time.zone.local(2026, 9, 3, 9)

      assert_equal Plan.fetch("premium"), @user.monthly_plan
      assert_equal Time.zone.local(2026, 9, 3, 9), @user.usage_refills_at
    end
  end

  test "an unsigned webhook is refused" do
    post "/purchasekit/webhooks", params: event("subscription.created", status: "active").to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :bad_request
    assert_not @user.subscribed?
  end

  private
    def deliver(type, status:, period: @period)
      body = event(type, status: status, period: period).to_json

      perform_enqueued_jobs do
        post "/purchasekit/webhooks", params: body, headers: {
          "Content-Type" => "application/json",
          "X-PurchaseKit-Signature" => OpenSSL::HMAC.hexdigest("SHA256", WEBHOOK_SECRET, body)
        }
      end
      assert_response :ok
    end

    def event(type, status:, period: @period)
      { event_id: SecureRandom.uuid, type: type, customer_id: @customer.id.to_s, subscription_id: "1000000123456789",
        store: "apple", store_product_id: "app.rokapi.premium.monthly", subscription_name: "default", status: status,
        current_period_start: period.begin.iso8601, current_period_end: period.end.iso8601, success_path: "/subscriptions/welcome" }
    end
end
