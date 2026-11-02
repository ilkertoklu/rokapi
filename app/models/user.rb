class User < ApplicationRecord
  include EmailChangeable, Allowance

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
    update! name: name, terms_accepted_at: terms_accepted_at || Time.current
  end

  def initial
    name.to_s.first
  end
end
