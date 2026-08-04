class Roll < ApplicationRecord
  DIE = 20
  REEL_CELLS = 17

  belongs_to :choice
  belongs_to :player

  has_one :scene, through: :choice

  scope :pending, -> { where(resolution: nil) }
  scope :unseen, -> { where(acknowledged_at: nil).where.not(resolution: nil) }

  after_create_commit :narrate_outcome_later
  after_update_commit -> { scene.game_session.broadcast_stage }

  def total
    value + modifier
  end

  def faces
    others = (1..DIE).to_a - [ value ]
    others.shuffle(random: Random.new(id)).first(REEL_CELLS - 1) << value
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

  def acknowledge!
    update! acknowledged_at: Time.current
    scene.game_session.continue_narration_later
  end

  def hp_change
    effects.to_h["hp"].to_i
  end

  def narrate_outcome
    Narrator.new(scene.game_session).narrate_outcome(self)
  end

  def narrate_outcome_later
    update! failed_at: nil if failed?
    Roll::NarrateJob.perform_later self
  end

  def narration_failed!
    update! failed_at: Time.current
  end

  def resolve!(resolution:, effects:)
    transaction do
      update! resolution: resolution, effects: effects, failed_at: nil
      apply_effects!
    end
  end

  private
    def apply_effects!
      return if hp_change.zero?

      character = player.character
      character.update! hp: (character.hp + hp_change).clamp(0, character.max_hp)
    end
end
