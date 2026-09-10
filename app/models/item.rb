class Item < ApplicationRecord
  class Unusable < StandardError; end

  MINIMUM_USES = 1

  belongs_to :character

  enum :kind, %w[instant passive quest].index_by(&:itself)

  normalizes :description, with: ->(description) { description.presence&.sub(/\A./) { |first| first.upcase } }

  scope :carried, -> { where(uses_left: nil).or(where(uses_left: 1..)) }
  scope :usable, -> { instant.where(uses_left: 1..) }
  scope :healing, -> { usable.where(hp_effect: 1..) }
  scope :used_since, ->(time) { where(used_at: time..) }

  def usable?
    instant? && uses_left.to_i.positive?
  end

  def use
    transaction do
      raise Unusable if self.class.usable.where(id: id).update_all([ "uses_left = uses_left - 1, used_at = ?", Time.current ]).zero?

      reload
      character.adjust_hp hp_effect
    end
  end

  def summary
    case
    when instant? then "#{name} (instant: #{format('%+d', hp_effect)} health, #{uses_left} #{"use".pluralize(uses_left)})"
    when quest?   then "#{name} (quest item)"
    when description.present? then "#{name} (#{description})"
    else name
    end
  end
end
