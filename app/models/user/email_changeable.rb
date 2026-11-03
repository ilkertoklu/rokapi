module User::EmailChangeable
  extend ActiveSupport::Concern

  CONFIRMATION_TIME = 24.hours

  included do
    normalizes :unconfirmed_email, with: ->(email) { email.strip.downcase.presence }

    validates :unconfirmed_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
    validate :unconfirmed_email_available, if: :unconfirmed_email_changed?

    after_update_commit :send_email_confirmation, if: :email_change_requested?

    generates_token_for :email_confirmation, expires_in: CONFIRMATION_TIME do
      unconfirmed_email
    end
  end

  def request_email_change(email)
    self.unconfirmed_email = email
    self.unconfirmed_email = nil if unconfirmed_email == self.email
  end

  def email_change_pending?
    unconfirmed_email.present?
  end

  def email_change_requested?
    saved_change_to_unconfirmed_email? && email_change_pending?
  end

  def confirm_email
    update! email: unconfirmed_email, unconfirmed_email: nil
  end

  private
    def send_email_confirmation
      EmailConfirmationMailer.with(user: self).confirmation.deliver_later
    end

    def unconfirmed_email_available
      errors.add :unconfirmed_email, :taken if User.where.not(id: id).exists?(email: unconfirmed_email)
    end
end
