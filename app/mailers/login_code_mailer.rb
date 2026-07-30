class LoginCodeMailer < ApplicationMailer
  def code
    @user = params[:user]
    @code = params[:code]

    mail to: @user.email, subject: "Rokapi kodun: #{@code}"
  end
end
