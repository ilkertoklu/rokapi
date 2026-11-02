module SubscriptionsHelper
  STORE_SUBSCRIPTIONS = {
    "apple" => "https://apps.apple.com/account/subscriptions",
    "google" => "https://play.google.com/store/account/subscriptions?package=app.rokapi"
  }.freeze

  def manage_subscription_url(subscription)
    STORE_SUBSCRIPTIONS.fetch(subscription.data.to_h.fetch("store", "apple"))
  end

  def subscription_renewal(subscription)
    l(subscription.current_period_end.to_date, format: :renewal) if subscription.current_period_end
  end

  def subscription_ending?(subscription)
    subscription.status == "canceled"
  end

  def subscription_status(subscription)
    case
    when subscription.nil? then "free"
    when subscription_ending?(subscription) then "ending"
    else "active"
    end
  end
end
