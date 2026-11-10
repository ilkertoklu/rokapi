module User::Subscriber
  extend ActiveSupport::Concern

  included do
    pay_customer default_payment_processor: :purchasekit

    before_destroy -> { pay_customers.destroy_all }
  end

  def subscription
    return @subscription if defined?(@subscription)

    @subscription = pay_subscriptions.order(created_at: :desc).find { |subscription| subscription.active? || paid_through?(subscription) }
  end

  def subscribed?
    subscription.present?
  end

  def reload(*)
    remove_instance_variable :@subscription if defined?(@subscription)
    super
  end

  private
    def paid_through?(subscription)
      subscription.status.inquiry.canceled? && (subscription.ends_at || subscription.current_period_end)&.future?
    end
end
