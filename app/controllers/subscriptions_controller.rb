class SubscriptionsController < ApplicationController
  def show
    @subscription = Current.user.subscription
  end
end
