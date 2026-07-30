class LoginCode < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRATION_TIME = 10.minutes
  MAX_ATTEMPTS = 5

  belongs_to :user

  scope :active, -> { where(expires_at: Time.current...).where(attempts_count: ...MAX_ATTEMPTS) }
  scope :stale, -> { where(expires_at: ..Time.current) }

  attr_reader :code

  before_create :generate_code
  before_create :set_expiration

  class << self
    def cleanup
      stale.delete_all
    end

    def digest(code)
      OpenSSL::HMAC.hexdigest "SHA256", Rails.application.secret_key_base, code.to_s
    end
  end

  def verify(candidate)
    if ActiveSupport::SecurityUtils.secure_compare(code_digest, self.class.digest(candidate))
      user.login_codes.delete_all
      true
    else
      increment! :attempts_count
      false
    end
  end

  private
    def generate_code
      @code = SecureRandom.random_number(10**CODE_LENGTH).to_s.rjust(CODE_LENGTH, "0")
      self.code_digest = self.class.digest(@code)
    end

    def set_expiration
      self.expires_at ||= EXPIRATION_TIME.from_now
    end
end
