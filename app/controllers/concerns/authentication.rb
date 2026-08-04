module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :resume_session, **options
    end

    def require_unauthenticated_access(**options)
      allow_unauthenticated_access(**options)
      before_action :redirect_authenticated_user, **options
    end
  end

  private
    def authenticated?
      Current.session.present?
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      if session = find_session_by_cookie
        set_current_session session.resumed
      end
    end

    def find_session_by_cookie
      Session.find_signed(cookies.signed[:session_token])
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to welcome_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        set_current_session session
      end
    end

    def set_current_session(session)
      Current.session = session
      cookies.signed.permanent[:session_token] = { value: session.signed_id, httponly: true, same_site: :lax }
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_token)
    end

    def redirect_authenticated_user
      redirect_to root_url if authenticated?
    end

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
