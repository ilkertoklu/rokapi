class Roll < ApplicationRecord
  DIE = 20
  REEL_CELLS = 17

  belongs_to :choice
  belongs_to :player

  has_one :scene, through: :choice

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

  def acknowledge
    update! acknowledged_at: Time.current
    scene.game_session.continue_narration_later
  end

  def hp_change
    effects.to_h["hp"].to_i
  end

  def items_gained
    Array(effects.to_h["items_gained"])
  end

  def statuses_gained
    Array(effects.to_h["statuses_gained"])
  end

  def narrate_outcome
    Narrator.new(scene.game_session).narrate_outcome(self)
  end

  def narrate_outcome_later
    update! failed_at: nil if failed?
    Roll::NarrateJob.perform_later self
  end

  def stall_narration
    update! failed_at: Time.current
  end

  def resolve(resolution:, effects:)
    transaction do
      update! resolution: resolution, effects: effects, failed_at: nil
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

      Array(effects.to_h["items_lost"]).each { |name| character.lose_item name }
      items_gained.each do |grant|
        character.gain_item name: grant["name"], kind: grant["kind"],
          description: grant["description"], hp: grant["hp"], uses: grant["uses"]
      end
      Array(effects.to_h["statuses_lost"]).each { |name| character.lose_status name }
      statuses_gained.each do |grant|
        character.gain_status name: grant["name"], modifier: grant["modifier"],
          turns: grant["turns"], expires_when: grant["expires_when"]
      end
    end
end
