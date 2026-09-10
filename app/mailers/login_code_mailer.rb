class LoginCodeMailer < ApplicationMailer
  def code
    login_code = params[:login_code]
    @code = login_code.code

    mail to: login_code.user.email, subject: "Your Rokapi code: #{@code}"
  end
end
