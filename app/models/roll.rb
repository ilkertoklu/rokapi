class Roll < ApplicationRecord
  DIE = 20
  HEALTH_FLOOR = { narrow: -3, failure: -6, heavy: -9, catastrophe: -12 }.freeze

  include Consequential, Stallable

  belongs_to :choice
  belongs_to :player

  has_one :scene, through: :choice

  delegate :modifier, :target, to: :choice
  delegate :game_session, to: :scene

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
    I18n.t(grade, scope: "roll.grades")
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
    Narrator.for(scene.game_session).narrate_outcome(self)
  end

  def narrate_later
    Roll::NarrateJob.perform_later self
  end

  def resolve(resolution:, effects:)
    transaction do
      ending = ending_with(effects)

      update! resolution: resolution, effects: recorded(effects.to_h), stalled_at: nil
      character.status_effects.each(&:tick)
      apply_effects
      scene.conclude ending if ending
    end
  end

  def ending_with(effects)
    if character.hp + bounded(effects.to_h)["hp"] <= 0
      "defeat"
    elsif scene.last?
      effects.to_h["outcome"].presence_in(%w[ victory defeat ])
    end
  end

  def clue_won
    scene.game_session.next_clue if success? && !scene.last?
  end

  def life_at_stake?
    character.hp + health_floor <= 0
  end

  private
    def recorded(effects)
      bounded(effects).merge(effects.slice("mark"), { "clue" => clue_won }.compact)
    end

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

    def character
      player.character
    end

    def health_floor
      HEALTH_FLOOR.fetch(grade, 0)
    end

    def boon?
      critical?
    end
end
