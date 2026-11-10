module ProfileCompletion
  extend ActiveSupport::Concern

  included do
    before_action :require_complete_profile
  end

  class_methods do
    def allow_incomplete_profile(**options)
      skip_before_action :require_complete_profile, **options
    end
  end

  private
    def require_complete_profile
      redirect_to new_signup_profile_path if authenticated? && !Current.user.profile_complete?
    end
end
