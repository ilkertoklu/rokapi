class HotwireNative::PathConfigurationsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :ensure_profile_complete

  def show
    render json: Rails.root.join("config/path_configuration.json").read
  end
end
