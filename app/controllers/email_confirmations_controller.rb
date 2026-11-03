class EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :ensure_profile_complete
  before_action :set_user

  def show
  end

  def update
    if @user.confirm_email
      redirect_to after_confirmation_path, notice: t(".confirmed", email: @user.email)
    else
      redirect_to after_confirmation_path, alert: t(".taken")
    end
  end

  private
    def set_user
      unless @user = User.find_by_token_for(:email_confirmation, params[:token])
        redirect_to after_confirmation_path, alert: t("email_confirmations.expired")
      end
    end

    def after_confirmation_path
      authenticated? ? my_settings_path : new_login_code_path
    end
end
