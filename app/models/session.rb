class Session < ApplicationRecord
  ACTIVITY_REFRESH_INTERVAL = 1.hour

  belongs_to :user

  before_create { self.last_active_at ||= Time.current }

  def resume
    update! last_active_at: Time.current if last_active_at < ACTIVITY_REFRESH_INTERVAL.ago
  end
end
