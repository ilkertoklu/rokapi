class LoginCodeMailer < ApplicationMailer
  def code
    login_code = params[:login_code]
    @code = login_code.code

    mail to: login_code.user.email, subject: default_i18n_subject(code: @code)
  end
end
