module LoginCodes
  extend ActiveSupport::Concern

  private
    def deliver_login_code_to(email)
      user = User.find_or_create_by!(email: email)
      login_code = user.send_login_code
      session[:pending_email] = user.email
      reveal_development_login_code login_code
    end

    def pending_user
      User.find_by(email: session[:pending_email]) if session[:pending_email].present?
    end

    def clear_pending_email
      session.delete(:pending_email)
    end

    def reveal_development_login_code(login_code)
      flash[:development_login_code] = login_code.code if Rails.env.development?
    end
end
