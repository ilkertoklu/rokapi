module GameSession::Dealt
  extend ActiveSupport::Concern

  included do
    validates :place, inclusion: { in: GameSession::Place.keys }, on: :create
    validates :trouble, inclusion: { in: GameSession::Trouble.keys }, on: :create
    validates :figure, inclusion: { in: GameSession::Figure.keys }, on: :create
    validates :twist, inclusion: { in: GameSession::Twist.keys }, on: :create

    before_validation :deal_card, on: :create, unless: :place?
    before_validation :draw_twist, on: :create, unless: :twist?
  end

  def title
    super.presence || (surprise? ? I18n.t("game_session.surprise_title") : card.place.text)
  end

  def card
    GameSession::Card.new(place: GameSession::Place.fetch(place), trouble: GameSession::Trouble.fetch(trouble), figure: GameSession::Figure.fetch(figure))
  end

  def card=(key)
    self.surprise = key.blank?
    self.place, self.trouble, self.figure = key.to_s.split
  end

  def new_place_for?(user)
    finished? && user.game_sessions.finished.where(place: place, ended_at: ...ended_at).none?
  end

  private
    def deal_card
      self.place, self.trouble, self.figure = GameSession::Card.deal(1, to: creator).first.keys
    end

    def draw_twist
      self.twist = GameSession::Trouble[trouble]&.twists&.sample
    end
end
