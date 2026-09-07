class LoginCode < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRATION_TIME = 10.minutes
  MAX_ATTEMPTS = 5

  belongs_to :user

  encrypts :code

  scope :active, -> { where(expires_at: Time.current...).where(attempts_count: ...MAX_ATTEMPTS) }
  scope :stale, -> { where(expires_at: ..Time.current) }

  before_create do
    self.code = SecureRandom.random_number(10**CODE_LENGTH).to_s.rjust(CODE_LENGTH, "0")
    self.expires_at ||= EXPIRATION_TIME.from_now
  end

  def self.cleanup
    stale.delete_all
  end

  def verify(candidate)
    if ActiveSupport::SecurityUtils.secure_compare(code, candidate.to_s)
      user.login_codes.delete_all
      true
    else
      increment! :attempts_count
      false
    end
  end
end
