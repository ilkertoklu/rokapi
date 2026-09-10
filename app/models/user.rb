class User < ApplicationRecord
  NAME_LENGTH = 40

  has_many :sessions, dependent: :delete_all
  has_many :login_codes, dependent: :delete_all
  has_many :players, dependent: :destroy
  has_many :game_sessions, through: :players

  normalizes :email, with: ->(email) { email.strip.downcase.presence }
  normalizes :name, with: ->(name) { name.squish.truncate(NAME_LENGTH, omission: "") }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def send_login_code
    login_codes.delete_all

    login_codes.create!.tap do |login_code|
      LoginCodeMailer.with(login_code: login_code).code.deliver_later
    end
  end

  def verify_login_code(code)
    login_codes.active.first&.verify(code)
  end

  def profile_complete?
    name.present? && terms_accepted_at.present?
  end

  def complete_profile(name:)
    update! name: name, terms_accepted_at: Time.current
  end

  def initial
    name.to_s.first&.upcase
  end
end
