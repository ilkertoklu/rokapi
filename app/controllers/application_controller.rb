class ApplicationController < ActionController::Base
  include Authentication
  include Localization
  include ProfileCompletion

  allow_browser versions: :modern

  stale_when_importmap_changes
end
