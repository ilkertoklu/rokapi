class LoginCodes::ResendsController < ApplicationController
  include PendingLogin

  require_unauthenticated_access
  rate_limit to: 3, within: 5.minutes,
    with: -> { redirect_to new_session_path, alert: "Too many code requests. Wait a few minutes." }

  def create
    if session[:pending_email].present?
      deliver_login_code_to session[:pending_email]
      redirect_to new_session_path, notice: "A new code is on its way."
    else
      redirect_to new_login_code_path
    end
  end
end
