class SignupsController < ApplicationController
  require_unauthenticated_access
  rate_limit to: 5, within: 3.minutes, only: :create,
    with: -> { redirect_to new_signup_path, alert: "Çok fazla deneme yapıldı. Birkaç dakika sonra tekrar dene." }

  def new
  end

  def create
    deliver_login_code_to email
    redirect_to new_sessions_code_path
  rescue ActiveRecord::RecordInvalid
    redirect_to new_signup_path, alert: "Geçerli bir e-posta adresi gir."
  end

  private
    def email
      params.expect(:email)
    end
end
