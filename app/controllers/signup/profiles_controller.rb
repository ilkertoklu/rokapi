class Signup::ProfilesController < ApplicationController
  allow_incomplete_profile

  def new
  end

  def create
    if Current.user.complete_profile(name: profile_params[:name], terms: profile_params[:terms])
      redirect_to signup_welcome_path
    else
      redirect_to new_signup_profile_path, alert: t(".terms_required")
    end
  end

  private
    def profile_params
      params.expect(user: %i[ name terms ])
    end
end
