class GameSession < ApplicationRecord
  class NotFound < StandardError; end
  class Full < StandardError; end
  class NotReady < StandardError; end

  PARTY_SIZE = 5
  CODE_LENGTH = 4
  JOINABLE_FOR = 24.hours
  EARLIER_SURPRISES = 5

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :rematch_of, class_name: "GameSession", optional: true

  has_one :rematch, class_name: "GameSession", foreign_key: :rematch_of_id, inverse_of: :rematch_of

  has_many :scenes, dependent: :destroy
  has_many :choices, through: :scenes
  has_many :rolls, through: :choices
  has_many :players, dependent: :destroy
  has_one :conversation, class_name: "Narrator::Conversation", dependent: :destroy

  enum :tone, Tone.keys.index_by(&:itself), default: "balanced", validate: true
  enum :length, Length.keys.index_by(&:itself), default: "medium", validate: true
  enum :outcome, %w[victory defeat].index_by(&:itself), prefix: true

  attribute :locale, default: -> { I18n.locale }

  normalizes :quest, with: ->(key) { key.presence }

  validates :quest, inclusion: { in: Quest.keys }, allow_nil: true
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validates :max_players, inclusion: { in: [ 1, PARTY_SIZE ] }

  scope :ongoing, -> { where(ended_at: nil) }
  scope :unstarted, -> { where(started_at: nil) }
  scope :rooms, -> { where.not(code: nil) }

  before_create :assign_code, if: -> { max_players > 1 }
  after_create -> { players.create!(user: creator) }
  after_create_commit -> { rematch_of.broadcast_refresh }, if: :rematch_of

  def self.open_for_join(code)
    rooms.unstarted.where(created_at: JOINABLE_FOR.ago..).find_by(code: code) || raise(NotFound)
  end

  def title
    Quest[quest]&.title || super.presence || I18n.t("game_session.surprise_title")
  end

  def player_for(user)
    players.find_by(user: user)
  end

  def host
    player_for(creator)
  end

  def party
    players.in_join_order.includes(:user, :character)
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

  def start_rematch(by:)
    with_lock do
      rematch || create_rematch!(creator: by, quest: quest, tone: tone, length: length, locale: locale, max_players: max_players).tap do |room|
        party.reject(&:departed?).each { |player| room.players.create!(user: player.user) unless player.user == by }
      end
    end
  end

  def survivors
    party.select { |player| player.character&.hp&.positive? }
  end

  def scene_budget
    Length.fetch(length).scenes
  end

  def earlier_surprises
    creator.created_game_sessions.where(quest: nil, created_at: ...created_at).where.not(title: [ nil, "" ])
      .order(created_at: :desc).limit(EARLIER_SURPRISES).pluck(:title)
  end

  def verdict
    rolls.where(success: true).count >= rolls.where(success: false).count ? "victory" : "defeat"
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
      elsif finale_next?(previous) && !previous.departed?
        previous
      else
        party = players.in_join_order.to_a
        party.rotate(party.index(previous) + 1).find { |player| !player.departed? }
      end
    end

    def finale_next?(previous)
      current_scene.position + 1 >= scene_budget || previous.character.hp.zero?
    end
end
