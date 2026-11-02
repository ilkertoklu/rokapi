class Subscriptions::WelcomesController < ApplicationController
  def show
    @subscription = Current.user.subscription
    @customer = Current.user.payment_processor
  end
end
