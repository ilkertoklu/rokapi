class SessionsController < ApplicationController
  include PendingLogin

  require_unauthenticated_access except: :destroy
  skip_before_action :ensure_profile_complete
  before_action :ensure_pending_email, only: %i[new create]
  rate_limit to: 10, within: 15.minutes, only: :create, by: -> { pending_email.to_s },
    with: -> { redirect_to new_session_path, alert: t(".rate_limited") }

  def new
  end

  def create
    if (user = pending_user) && user.verify_login_code(params.expect(:code))
      clear_pending_email
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: t(".wrong_code")
    end
  end

  def destroy
    terminate_session
    redirect_to welcome_path
  end

  private
    def ensure_pending_email
      redirect_to new_login_code_path if pending_email.blank?
    end
end
