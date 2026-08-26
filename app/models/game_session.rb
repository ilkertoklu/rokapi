class GameSession < ApplicationRecord
  TONES = { "fun" => "Eğlenceli", "balanced" => "Dengeli", "dark" => "Karanlık" }.freeze
  LENGTHS = { "short" => "Kısa", "medium" => "Orta", "long" => "Uzun" }.freeze

  SCENE_BUDGETS = { "short" => 7, "medium" => 12, "long" => 18 }.freeze

  belongs_to :adventure, optional: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :scenes, dependent: :destroy
  has_many :choices, through: :scenes
  has_many :rolls, through: :choices
  has_many :players, dependent: :destroy
  has_many :llm_calls, dependent: :destroy

  enum :mode, %w[solo multi].index_by(&:itself)
  enum :tone, TONES.keys.index_by(&:itself), default: "balanced"
  enum :length, LENGTHS.keys.index_by(&:itself), default: "medium"
  enum :state, %w[lobby playing finished].index_by(&:itself), default: "lobby"
  enum :outcome, %w[victory defeat].index_by(&:itself), prefix: true

  scope :ongoing, -> { where.not(state: :finished) }

  after_create -> { players.create!(user: creator, host: true) }
  after_update_commit :continue_narration_later, if: -> { playing? && state_previously_changed? }

  def title
    adventure&.title || story_bible&.dig("title").presence || "Sürpriz macera"
  end

  def player_for(user)
    players.find_by(user: user)
  end

  def start_when_ready!
    update! state: :playing if lobby? && players.where(ready: false).none?
  end

  def scene_budget
    SCENE_BUDGETS.fetch(length)
  end

  def current_scene
    scenes.chronological.last
  end

  def pending_roll
    rolls.pending.order(:id).first
  end

  def unseen_roll
    rolls.unseen.order(:id).first
  end

  def acknowledge_roll!
    unseen_roll&.acknowledge!
  end

  def stalled_work
    roll = pending_roll
    return roll if roll&.failed?

    scene = current_scene
    scene if scene&.failed?
  end

  def broadcast_stage
    broadcast_replace_to self, target: :game_stage, partial: "game_sessions/stage",
      attributes: { method: :morph }
  end

  def finish!(outcome)
    update! state: :finished, outcome: outcome, ended_at: Time.current
  end

  def duration
    ended_at - created_at
  end

  def survivors_count
    players.joins(:character).where(characters: { hp: 1.. }).count
  end

  def continue_narration
    Narrator.new(self).continue!
  end

  def continue_narration_later
    Scene::GenerateJob.perform_later self
  end

  def narration_failed!
    current_scene&.failed!
  end

  def resume_narration!
    case (stuck = stalled_work)
    when Roll
      stuck.narrate_outcome_later
    when Scene
      stuck.narrating!
      continue_narration_later
    else
      continue_narration_later unless current_scene&.narrating?
    end
  end
end
