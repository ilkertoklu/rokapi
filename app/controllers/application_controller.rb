class ApplicationController < ActionController::Base
  include Authentication
  include Localization

  allow_browser versions: :modern

  stale_when_importmap_changes

  before_action :ensure_profile_complete

  private
    def ensure_profile_complete
      redirect_to new_signup_profile_path if authenticated? && !Current.user.profile_complete?
    end
end
