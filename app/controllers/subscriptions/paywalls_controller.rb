class Subscriptions::PaywallsController < ApplicationController
  def show
    @customer = Current.user.payment_processor
  end
end
