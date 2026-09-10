class SessionsController < ApplicationController
  include PendingLogin

  require_unauthenticated_access except: :destroy
  skip_before_action :ensure_profile_complete
  before_action :ensure_pending_email, only: %i[new create]
  rate_limit to: 10, within: 15.minutes, only: :create,
    with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again in 15 minutes." }

  def new
  end

  def create
    if (user = pending_user) && user.verify_login_code(params.expect(:code))
      clear_pending_email
      start_new_session_for user
      redirect_to user.profile_complete? ? after_authentication_url : new_signup_profile_path
    else
      redirect_to new_session_path, alert: "That code is wrong or has expired. Try again."
    end
  end

  def destroy
    terminate_session
    redirect_to welcome_path
  end

  private
    def ensure_pending_email
      redirect_to new_login_code_path if session[:pending_email].blank?
    end
end
