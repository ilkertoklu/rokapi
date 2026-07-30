class Signup::ProfilesController < ApplicationController
  skip_before_action :ensure_profile_complete

  def new
  end

  def create
    if terms_accepted?
      Current.user.complete_profile! name: name
      redirect_to signup_welcome_path
    else
      redirect_to new_signup_profile_path, alert: "Devam etmek için koşulları kabul etmelisin."
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to new_signup_profile_path, alert: "Adını yaz."
  end

  private
    def name
      params.expect(:name)
    end

    def terms_accepted?
      params[:terms] == "1"
    end
end
