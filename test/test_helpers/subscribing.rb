module Subscribing
  def subscribe(user, plan_key, status: "active", period: Time.current...1.month.from_now)
    Pay::Purchasekit::Subscription.create! customer: user.payment_processor, name: "default", quantity: 1,
      processor_id: "sub_#{SecureRandom.hex(6)}", processor_plan: Plan.fetch(plan_key).store_product_ids.first,
      status: status, current_period_start: period.begin, current_period_end: period.end
  end
end
