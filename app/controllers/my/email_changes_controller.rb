class My::EmailChangesController < ApplicationController
  def show
    redirect_to my_settings_path unless Current.user.email_change_pending?
  end
end
