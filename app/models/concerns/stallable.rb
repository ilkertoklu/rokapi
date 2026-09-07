module Stallable
  extend ActiveSupport::Concern

  def stalled?
    stalled_at.present?
  end

  def stall_narration
    update! stalled_at: Time.current
  end

  def resume_narration
    update! stalled_at: nil
    narrate_later
  end
end
