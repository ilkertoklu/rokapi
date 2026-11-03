class My::SettingsController < ApplicationController
  rate_limit to: 5, within: 3.minutes, only: :update,
    with: -> { redirect_to my_settings_path, alert: t(".rate_limited") }

  def show
  end

  def update
    Current.user.update_settings name: settings_params[:name], email: settings_params[:email]

    respond_to do |format|
      format.html { redirect_after_saving }
      format.json { render :show }
    end
  rescue ActiveRecord::RecordInvalid => invalid
    respond_to do |format|
      format.html { render :show, status: :unprocessable_entity }
      format.json { render json: invalid.record.errors, status: :unprocessable_entity }
    end
  end

  private
    def settings_params
      params.expect(user: %i[ name email ])
    end

    def redirect_after_saving
      if Current.user.email_change_requested?
        redirect_to my_email_change_path
      else
        redirect_to my_settings_path, notice: t(".saved")
      end
    end
end
