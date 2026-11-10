class HotwireNative::PathConfigurationsController < ApplicationController
  allow_unauthenticated_access
  allow_incomplete_profile

  def show
    render json: Rails.root.join("config/path_configuration.json").read
  end
end
