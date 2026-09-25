class LoginCodesController < ApplicationController
  include PendingLogin

  require_unauthenticated_access
  rate_limit to: 5, within: 3.minutes, only: :create,
    with: -> { redirect_back_or_to new_login_code_path, alert: t(".rate_limited") }

  def new
  end

  def create
    deliver_login_code_to params.expect(:email)
    redirect_to new_session_path
  rescue ActiveRecord::RecordInvalid
    redirect_back_or_to new_login_code_path, alert: t(".invalid_email")
  end
end
