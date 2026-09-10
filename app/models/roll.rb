class Roll < ApplicationRecord
  DIE = 20
  GRADE_LABELS = {
    critical: "CRITICAL SUCCESS", brilliant: "BRILLIANT SUCCESS", solid: "SUCCESS", narrow: "NARROW SUCCESS",
    failure: "FAILURE", heavy: "HEAVY FAILURE", catastrophe: "CATASTROPHE"
  }.freeze
  EMPTY_EFFECTS = { "hp" => 0, "items_gained" => [], "items_lost" => [], "statuses_gained" => [], "statuses_lost" => [] }.freeze

  include Stallable

  belongs_to :choice
  belongs_to :player

  has_one :scene, through: :choice

  delegate :modifier, :target, to: :choice

  store_accessor :effects, :hp, suffix: :change
  store_accessor :effects, :items_gained, :items_lost, :statuses_gained, :statuses_lost

  normalizes :effects, with: ->(effects) { EMPTY_EFFECTS.merge(effects.to_h.deep_stringify_keys) }

  before_create { self.success = total >= target }

  after_create_commit :narrate_later
  after_update_commit -> { broadcast_refresh_to scene.game_session }

  def total
    value + modifier + status_modifier
  end

  def margin
    total - target
  end

  def grade
    success? ? success_grade : failure_grade
  end

  def grade_label
    GRADE_LABELS.fetch(grade)
  end

  def resolved?
    resolution.present?
  end

  def pending?
    !resolved?
  end

  def critical?
    grade == :critical
  end

  def acknowledged?
    acknowledged_at.present?
  end

  def unseen?
    resolved? && !acknowledged?
  end

  def acknowledge
    if unseen?
      transaction do
        update! acknowledged_at: Time.current
        scene.game_session.advance
      end
    end
  end

  def narrate
    Narrator.new(scene.game_session).narrate_outcome(self)
  end

  def narrate_later
    Roll::NarrateJob.perform_later self
  end

  def resolve(resolution:, effects:)
    transaction do
      update! resolution: resolution, effects: effects
      apply_effects
    end
  end

  private
    def success_grade
      case
      when value == DIE then :critical
      when margin >= 5 then :brilliant
      when margin <= 1 then :narrow
      else :solid
      end
    end

    def failure_grade
      case
      when value == 1 then :catastrophe
      when margin <= -5 then :heavy
      else :failure
      end
    end

    def apply_effects
      character = player.character
      character.status_effects.each(&:tick)
      character.adjust_hp hp_change

      items_lost.each { |name| character.lose_item name }
      items_gained.each { |item| character.items.create! item }
      statuses_lost.each { |name| character.lose_status name }
      statuses_gained.each { |status| character.gain_status(**status.symbolize_keys) }
    end
end
