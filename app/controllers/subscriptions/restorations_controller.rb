class Subscriptions::RestorationsController < ApplicationController
  def create
    if Current.user.subscribed?
      redirect_to subscription_path, notice: t(".restored")
    else
      redirect_to subscription_path, alert: t(".nothing_to_restore")
    end
  end
end
