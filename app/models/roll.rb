class Roll < ApplicationRecord
  DIE = 20
  HEALTH_FLOOR = { narrow: -3, failure: -6, heavy: -9, catastrophe: -12 }.freeze
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
      update! resolution: resolution, effects: bounded(effects.to_h)
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

    def bounded(effects)
      statuses_lost = Array(effects["statuses_lost"])
      statuses_gained = Array(effects["statuses_gained"]).map { |grant| status_from(grant) }.select { |status| critical? || !status["modifier"].positive? }
      kept = player.character.status_effects.map(&:name) - statuses_lost - statuses_gained.pluck("name")

      { "hp" => effects["hp"].to_i.clamp(HEALTH_FLOOR.fetch(grade, 0), 0),
        "items_gained" => Array(effects["items_gained"]).map { |grant| item_from(grant) },
        "items_lost" => Array(effects["items_lost"]),
        "statuses_gained" => statuses_gained.first([ StatusEffect::LIMIT - kept.size, 0 ].max),
        "statuses_lost" => statuses_lost }
    end

    def item_from(grant)
      instant = grant["kind"] == "instant"

      { "name" => grant["name"], "kind" => grant["kind"], "description" => grant["description"],
        "hp_effect" => instant ? grant["hp"].to_i : 0,
        "uses_left" => ([ grant["uses"].to_i, Item::MINIMUM_USES ].max if instant) }
    end

    def status_from(grant)
      turns = grant["turns"].to_i
      expires_when = grant["expires_when"].presence

      { "name" => grant["name"], "modifier" => grant["modifier"].to_i.clamp(StatusEffect::MODIFIER_RANGE), "expires_when" => expires_when,
        "turns_left" => turns.positive? ? turns.clamp(StatusEffect::TURNS) : (StatusEffect::DEFAULT_TURNS if expires_when.nil?) }
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
