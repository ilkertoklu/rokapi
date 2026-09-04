class Roll < ApplicationRecord
  DIE = 20
  GRADE_LABELS = {
    critical: "KRİTİK BAŞARI", brilliant: "PARLAK BAŞARI", solid: "BAŞARILI", narrow: "KIL PAYI BAŞARI",
    failure: "BAŞARISIZ", heavy: "AĞIR BAŞARISIZLIK", catastrophe: "FELAKET"
  }.freeze
  EMPTY_EFFECTS = { "hp" => 0, "items_gained" => [], "items_lost" => [], "statuses_gained" => [], "statuses_lost" => [] }.freeze

  belongs_to :choice
  belongs_to :player

  has_one :scene, through: :choice

  store_accessor :effects, :hp, suffix: :change
  store_accessor :effects, :items_gained, :items_lost, :statuses_gained, :statuses_lost

  normalizes :effects, with: ->(effects) { EMPTY_EFFECTS.merge(effects.to_h) }

  scope :pending, -> { where(resolution: nil) }
  scope :unseen, -> { where(acknowledged_at: nil).where.not(resolution: nil) }

  before_create { self.success = total >= target }

  after_create_commit :narrate_outcome_later
  after_update_commit -> { scene.game_session.broadcast_stage }

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

  def failed?
    failed_at.present?
  end

  def acknowledged?
    acknowledged_at.present?
  end

  def acknowledge
    update! acknowledged_at: Time.current
    scene.game_session.continue_narration_later
  end

  def narrate_outcome
    Narrator.new(scene.game_session).narrate_outcome(self)
  end

  def narrate_outcome_later
    Roll::NarrateJob.perform_later self
  end

  def stall_narration
    update! failed_at: Time.current
  end

  def resume_narration
    update! failed_at: nil
    narrate_outcome_later
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
