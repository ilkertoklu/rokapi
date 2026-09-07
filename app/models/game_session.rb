class GameSession < ApplicationRecord
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :scenes, dependent: :destroy
  has_many :choices, through: :scenes
  has_many :rolls, through: :choices
  has_many :players, dependent: :destroy
  has_many :llm_calls, dependent: :delete_all

  enum :tone, Tone.keys.index_by(&:itself), default: "balanced", validate: true
  enum :length, Length.keys.index_by(&:itself), default: "medium", validate: true
  enum :outcome, %w[victory defeat].index_by(&:itself), prefix: true

  normalizes :quest, with: ->(key) { key.presence }

  validates :quest, inclusion: { in: Quest.keys }, allow_nil: true

  store_accessor :story_bible, :title, :premise, :personal_stake, :antagonist, :ally, :twist, :beats,
    :finale_question, :victory, :defeat, prefix: :story

  scope :ongoing, -> { where(ended_at: nil) }

  after_create -> { players.create!(user: creator) }

  def title
    Quest[quest]&.title || story_title.presence || "Sürpriz macera"
  end

  def player_for(user)
    players.find_by(user: user)
  end

  def host
    player_for(creator)
  end

  def started?
    started_at.present?
  end

  def start_when_ready
    if !started? && players.where.missing(:character).none?
      update! started_at: Time.current
      advance
    end
  end

  def advance
    scenes.create!(position: scenes.maximum(:position).to_i + 1, active_player: host).narrate_later
  end

  def scene_budget
    Length.fetch(length).scenes
  end

  def current_scene
    scenes.chronological.last
  end

  def stalled_narration
    scene = current_scene
    [ scene&.roll, scene ].compact.find(&:stalled?)
  end

  def finished?
    ended_at.present?
  end

  def finish(outcome)
    update! outcome: outcome, ended_at: Time.current
  end

  def duration
    ended_at - started_at
  end

  def resume_narration
    if (stalled = stalled_narration)
      stalled.resume_narration
    elsif current_scene&.narrating?
      current_scene.narrate_later
    end
  end
end
