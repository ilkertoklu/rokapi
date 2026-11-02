class EmailConfirmationMailer < ApplicationMailer
  def confirmation
    user = params[:user]
    @url = email_confirmation_url(user.generate_token_for(:email_confirmation))

    mail to: user.unconfirmed_email, subject: default_i18n_subject
  end
end
