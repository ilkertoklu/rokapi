class Choice < ApplicationRecord
  DIFFICULTY = 5..19
  TARGETS = { "easy" => 7, "medium" => 10, "hard" => 13 }.freeze

  belongs_to :scene

  has_one :roll, dependent: :delete

  normalizes :target, with: ->(target) { target.clamp(DIFFICULTY) }

  scope :chosen, -> { where.not(chosen_at: nil) }

  def self.target_for(difficulty)
    TARGETS.fetch(difficulty.to_s.strip.downcase) { Integer(difficulty, exception: false) || TARGETS.fetch("medium") }
  end

  def stat_value
    scene.active_player.character.stats.fetch(stat)
  end

  def difficulty
    case
    when easy? then "easy"
    when hard? then "hard"
    else "medium"
    end
  end

  def difficulty_label
    I18n.t(difficulty, scope: "choice.difficulties")
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

  private
    def easy? = target < TARGETS.fetch("medium")
    def hard? = target >= TARGETS.fetch("hard")
end
