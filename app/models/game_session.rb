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
  has_many :llm_calls, dependent: :delete_all

  enum :mode, %w[solo multi].index_by(&:itself)
  enum :tone, TONES.keys.index_by(&:itself), default: "balanced", validate: true
  enum :length, LENGTHS.keys.index_by(&:itself), default: "medium", validate: true
  enum :state, %w[lobby playing].index_by(&:itself), default: "lobby"
  enum :outcome, %w[victory defeat].index_by(&:itself), prefix: true

  store_accessor :story_bible, :title, :premise, :personal_stake, :antagonist, :ally, :twist, :beats,
    :finale_question, :victory, :defeat, prefix: :story

  scope :ongoing, -> { where(ended_at: nil) }

  after_create -> { players.create!(user: creator) }

  def title
    adventure&.title || story_title.presence || "Sürpriz macera"
  end

  def player_for(user)
    players.find_by(user: user)
  end

  def start_when_ready
    if lobby? && players.where.missing(:character).none?
      update! state: :playing
      continue_narration_later
    end
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

  def acknowledge_roll
    unseen_roll&.acknowledge
  end

  def stalled_work
    [ pending_roll, current_scene ].compact.find(&:failed?)
  end

  def broadcast_stage
    broadcast_replace_to self, target: :game_stage, partial: "game_sessions/stage",
      attributes: { method: :morph }
  end

  def finished?
    ended_at.present?
  end

  def finish(outcome)
    update! outcome: outcome, ended_at: Time.current
  end

  def duration
    ended_at - created_at
  end

  def survivors_count
    players.joins(:character).where(characters: { hp: 1.. }).count
  end

  def continue_narration
    Narrator.new(self).continue
  end

  def continue_narration_later
    Scene::GenerateJob.perform_later self
  end

  def stall_narration
    current_scene&.stall_narration
  end

  def resume_narration
    if (stuck = stalled_work)
      stuck.resume_narration
    elsif !current_scene&.narrating?
      continue_narration_later
    end
  end
end
