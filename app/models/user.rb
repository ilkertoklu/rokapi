class User < ApplicationRecord
  include EmailChangeable, Subscriber, Allowance

  NAME_LENGTH = 40

  has_many :sessions, dependent: :delete_all
  has_many :login_codes, dependent: :delete_all
  has_many :created_game_sessions, class_name: "GameSession", foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :created_scenes, through: :created_game_sessions, source: :scenes
  has_many :players
  has_many :game_sessions, through: :players

  before_destroy -> { players.reload.each(&:depart) }

  normalizes :email, with: ->(email) { email.strip.downcase.presence }
  normalizes :name, with: ->(name) { name.squish.truncate(NAME_LENGTH, omission: "") }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :terms, acceptance: { allow_nil: false }, on: :signup
  validates :name, presence: true, on: :settings

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

  def complete_profile(name:, terms:)
    self.terms_accepted_at ||= Time.current
    assign_attributes name: name, terms: terms
    save context: :signup
  end

  def update_settings(name:, email:)
    self.name = name
    request_email_change email
    save context: :settings
  end

  def initial
    name.to_s.first
  end

  def record
    Record.new(self)
  end
end
