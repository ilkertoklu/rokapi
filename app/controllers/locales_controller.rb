class LocalesController < ApplicationController
  allow_unauthenticated_access
  allow_incomplete_profile

  def update
    locale = params.expect(:locale)
    cookies.permanent[:locale] = locale if I18n.locale_available?(locale)

    redirect_back_or_to root_path
  end
end
