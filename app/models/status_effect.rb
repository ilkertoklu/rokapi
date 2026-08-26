class StatusEffect < ApplicationRecord
  belongs_to :character

  def positive?
    modifier.positive?
  end

  def duration_label
    turns_left ? "#{turns_left} tur" : expires_when
  end

  def summary
    "#{name} (#{format('%+d', modifier)} zar, #{duration_label})"
  end

  def tick
    return if turns_left.nil?

    turns_left > 1 ? update!(turns_left: turns_left - 1) : destroy!
  end
end
