class LocalesController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :ensure_profile_complete

  def update
    locale = params.expect(:locale)
    cookies.permanent[:locale] = locale if I18n.locale_available?(locale)

    redirect_back_or_to root_path
  end
end
