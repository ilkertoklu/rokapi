class GameSession < ApplicationRecord
  class NotFound < StandardError; end
  class Full < StandardError; end
  class NotReady < StandardError; end

  PARTY_SIZE = 5
  CODE_LENGTH = 4
  JOINABLE_FOR = 24.hours
  LATEST = 5

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :rematch_of, class_name: "GameSession", optional: true

  has_one :rematch, class_name: "GameSession", foreign_key: :rematch_of_id, inverse_of: :rematch_of

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

  validates :place, inclusion: { in: Place.keys }, on: :create
  validates :trouble, inclusion: { in: Trouble.keys }, on: :create
  validates :figure, inclusion: { in: Figure.keys }, on: :create
  validates :twist, inclusion: { in: Twist.keys }, on: :create
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validates :max_players, inclusion: { in: [ 1, PARTY_SIZE ] }

  scope :ongoing, -> { where(ended_at: nil) }
  scope :unstarted, -> { where(started_at: nil) }
  scope :rooms, -> { where.not(code: nil) }
  scope :latest, -> { order(created_at: :desc).limit(LATEST) }

  before_validation :deal_card, on: :create, unless: :place?
  before_validation :draw_twist, on: :create, unless: :twist?
  before_create :assign_code, if: -> { max_players > 1 }
  after_create -> { players.create!(user: creator) }
  after_create_commit -> { rematch_of.broadcast_refresh }, if: :rematch_of

  def self.open_for_join(code)
    rooms.unstarted.where(created_at: JOINABLE_FOR.ago..).find_by(code: code) || raise(NotFound)
  end

  def title
    super.presence || (surprise? ? I18n.t("game_session.surprise_title") : card.place.text)
  end

  def card
    Card.new(place: Place.fetch(place), trouble: Trouble.fetch(trouble), figure: Figure.fetch(figure))
  end

  def card=(key)
    self.surprise = key.blank?
    self.place, self.trouble, self.figure = key.to_s.split
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
      rematch || create_rematch!(creator: by, surprise: surprise, tone: tone, length: length, locale: locale, max_players: max_players).tap do |room|
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

  def clues_found
    rolls.filter_map { Integer(it.effects&.dig("clue"), exception: false) }.select(&:positive?).uniq.sort
  end

  def plan_story
    update! plan: Narrator::Planner.for(self).plan
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
    def deal_card
      self.place, self.trouble, self.figure = Card.deal(1, to: creator).first.keys
    end

    def draw_twist
      self.twist = Trouble[trouble]&.twists&.sample
    end

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
      else
        party = players.in_join_order.to_a
        party.rotate(party.index(previous) + 1).find { |player| !player.departed? }
      end
    end
end
