class EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :ensure_profile_complete

  def show
    if (user = User.find_by_token_for(:email_confirmation, params[:token]))
      user.confirm_email
      redirect_to after_confirmation_path, notice: t(".confirmed", email: user.email)
    else
      redirect_to after_confirmation_path, alert: t(".expired")
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to after_confirmation_path, alert: t(".taken")
  end

  private
    def after_confirmation_path
      authenticated? ? my_settings_path : new_login_code_path
    end
end
