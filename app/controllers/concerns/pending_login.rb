module PendingLogin
  extend ActiveSupport::Concern

  private
    def deliver_login_code_to(email)
      user = User.find_or_create_by!(email: email)
      user.send_login_code
      session[:pending_email] = user.email
    end

    def pending_user
      User.find_by(email: session[:pending_email]) if session[:pending_email].present?
    end

    def clear_pending_email
      session.delete(:pending_email)
    end
end
