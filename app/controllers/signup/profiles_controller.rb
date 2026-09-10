class Signup::ProfilesController < ApplicationController
  skip_before_action :ensure_profile_complete

  def new
  end

  def create
    if terms_accepted?
      Current.user.complete_profile name: params.expect(:name)
      redirect_to signup_welcome_path
    else
      redirect_to new_signup_profile_path, alert: "You need to accept the terms to continue."
    end
  end

  private
    def terms_accepted?
      params[:terms] == "1"
    end
end
