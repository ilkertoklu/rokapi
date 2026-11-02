class GameSession < ApplicationRecord
  class NotFound < StandardError; end
  class Full < StandardError; end
  class NotReady < StandardError; end

  PARTY_SIZE = 5
  CODE_LENGTH = 4
  JOINABLE_FOR = 24.hours

  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :scenes, dependent: :destroy
  has_many :choices, through: :scenes
  has_many :rolls, through: :choices
  has_many :players, dependent: :destroy
  has_many :llm_calls, dependent: :delete_all

  enum :tone, Tone.keys.index_by(&:itself), default: "balanced", validate: true
  enum :length, Length.keys.index_by(&:itself), default: "medium", validate: true
  enum :outcome, %w[victory defeat].index_by(&:itself), prefix: true

  attribute :locale, default: -> { I18n.locale }

  normalizes :quest, with: ->(key) { key.presence }

  validates :quest, inclusion: { in: Quest.keys }, allow_nil: true
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validates :max_players, inclusion: { in: [ 1, PARTY_SIZE ] }

  store_accessor :story_bible, :title, :premise, :personal_stake, :antagonist, :ally, :twist, :beats,
    :finale_question, :victory, :defeat, prefix: :story

  scope :ongoing, -> { where(ended_at: nil) }
  scope :unstarted, -> { where(started_at: nil) }
  scope :rooms, -> { where.not(code: nil) }

  before_create :assign_code, if: -> { max_players > 1 }
  after_create -> { players.create!(user: creator) }

  def self.open_for_join(code)
    rooms.unstarted.where(created_at: JOINABLE_FOR.ago..).find_by(code: code) || raise(NotFound)
  end

  def title
    Quest[quest]&.title || story_title.presence || I18n.t("game_session.surprise_title")
  end

  def player_for(user)
    players.find_by(user: user)
  end

  def host
    player_for(creator)
  end

  def multiplayer?
    code.present?
  end

  def lobby?
    multiplayer? && !started?
  end

  def full?
    players.count >= max_players
  end

  def join(user)
    with_lock do
      player_for(user) || enroll(user)
    end
  end

  def everyone_ready?
    players.where.missing(:character).none?
  end

  def started?
    started_at.present?
  end

  def start(by:)
    with_lock do
      raise NotReady unless by == host && everyone_ready?
      begin_play unless started?
    end
  end

  def start_when_ready
    begin_play if !multiplayer? && !started? && everyone_ready?
  end

  def advance
    scenes.create!(position: scenes.maximum(:position).to_i + 1, active_player: next_active_player).narrate_later
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
    def assign_code
      self.code = loop do
        candidate = SecureRandom.random_number(10**CODE_LENGTH).to_s.rjust(CODE_LENGTH, "0")
        break candidate unless GameSession.unstarted.exists?(code: candidate)
      end
    end

    def enroll(user)
      raise NotFound if started?
      raise Full if full?

      players.create!(user: user)
    end

    def begin_play
      update! started_at: Time.current
      advance
    end

    def next_active_player
      previous = current_scene&.active_player

      if previous.nil?
        host
      elsif finale_next?(previous)
        previous
      else
        party = players.in_join_order.to_a
        party[(party.index(previous) + 1) % party.size]
      end
    end

    def finale_next?(previous)
      current_scene.position + 1 >= scene_budget || previous.character.hp.zero?
    end
end
