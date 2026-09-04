class SessionsController < ApplicationController
  require_unauthenticated_access except: :destroy
  skip_before_action :ensure_profile_complete
  rate_limit to: 5, within: 3.minutes, only: :create,
    with: -> { redirect_back_or_to new_session_path, alert: "Çok fazla deneme yapıldı. Birkaç dakika sonra tekrar dene." }

  def new
  end

  def create
    deliver_login_code_to email
    redirect_to new_sessions_code_path
  rescue ActiveRecord::RecordInvalid
    redirect_back_or_to new_session_path, alert: "Geçerli bir e-posta adresi gir."
  end

  def destroy
    terminate_session
    redirect_to welcome_path
  end

  private
    def email
      params.expect(:email)
    end
end
