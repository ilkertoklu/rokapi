class GameSession < ApplicationRecord
  class NotReady < StandardError; end

  belongs_to :creator, class_name: "User", default: -> { Current.user }

  include Clues, Dealt, Joinable, Planned, Rematchable

  LATEST = 5

  has_many :scenes, dependent: :destroy
  has_many :choices, through: :scenes
  has_many :rolls, through: :choices
  has_many :players, dependent: :destroy
  has_many :conversations, class_name: "Narrator::Conversation", dependent: :destroy
  has_one :conversation, -> { narration }, class_name: "Narrator::Conversation"

  enum :tone, Tone.keys.index_by(&:itself), default: "balanced", validate: true
  enum :length, Length.keys.index_by(&:itself), default: "medium", validate: true
  enum :outcome, %w[victory defeat].index_by(&:itself), prefix: true

  attribute :locale, default: -> { I18n.locale }

  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }

  scope :ongoing, -> { where(ended_at: nil) }
  scope :finished, -> { where.not(ended_at: nil) }
  scope :recently_finished_first, -> { finished.order(ended_at: :desc) }
  scope :unstarted, -> { where(started_at: nil) }
  scope :latest, -> { order(created_at: :desc).limit(LATEST) }

  after_create -> { players.create!(user: creator) }

  def player_for(user)
    players.find_by(user: user)
  end

  def host
    player_for(creator)
  end

  def party
    players.in_join_order.includes(:user, :character)
  end

  def everyone_ready?
    players.where.missing(:character).none?
  end

  def started?
    started_at.present?
  end

  def start
    with_lock do
      raise NotReady unless everyone_ready?
      begin_play unless started?
    end
  end

  def start_when_ready
    begin_play if !multiplayer? && !started? && everyone_ready?
  end

  def advance
    scenes.create!(position: scenes.maximum(:position).to_i + 1, active_player: next_active_player).narrate_later
  end

  def dice_rolled
    @dice_rolled ||= rolls.count
  end

  def scene_budget
    Length.fetch(length).scenes
  end

  def tone_label
    Tone.fetch(tone).label
  end

  def length_label
    Length.fetch(length).label
  end

  def length_estimate
    Length.fetch(length).estimate
  end

  def cost
    RubyLLM::Cost.aggregate(conversations.includes(:ruby_llm_usages).map(&:cost))
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

  def finish
    update! ended_at: Time.current
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

  private
    def begin_play
      update! started_at: Time.current
      advance
    end

    def next_active_player
      previous = current_scene&.active_player

      if previous.nil?
        host
      else
        party = players.in_join_order.to_a
        party.rotate(party.index(previous) + 1).find(&:standing?)
      end
    end
end
