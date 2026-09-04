class Sessions::ResendsController < ApplicationController
  include LoginCodes

  require_unauthenticated_access
  rate_limit to: 3, within: 5.minutes,
    with: -> { redirect_to new_sessions_code_path, alert: "Çok sık kod istendi. Birkaç dakika bekle." }

  def create
    if session[:pending_email].present?
      deliver_login_code_to session[:pending_email]
      redirect_to new_sessions_code_path, notice: "Yeni kod gönderildi."
    else
      redirect_to new_session_path
    end
  end
end
