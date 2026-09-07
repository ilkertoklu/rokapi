class Choice < ApplicationRecord
  TARGET_RANGE = 5..19

  belongs_to :scene

  has_one :roll, dependent: :delete

  normalizes :target, with: ->(target) { target.clamp(TARGET_RANGE) }

  scope :chosen, -> { where.not(chosen_at: nil) }

  def stat_value
    scene.active_player.character.stats.fetch(stat)
  end

  def easy? = target <= 11
  def hard? = target >= 16

  def difficulty
    case
    when easy? then "kolay"
    when hard? then "zor"
    else "orta"
    end
  end

  def chosen?
    chosen_at.present?
  end

  def choose
    transaction do
      raise Scene::OutOfTurn unless scene.choosing?

      update! chosen_at: Time.current
      scene.rolling!
    end
  end

  def roll_dice(by:)
    create_roll! player: by, value: rand(1..Roll::DIE), status_modifier: by.character.status_modifier
  end
end
