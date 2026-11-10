module GameSession::Joinable
  extend ActiveSupport::Concern

  class NotFound < StandardError; end
  class Full < StandardError; end

  PARTY_SIZE = 5
  CODE_LENGTH = 4
  JOINABLE_FOR = 24.hours

  included do
    validates :max_players, inclusion: { in: [ 1, PARTY_SIZE ] }

    scope :rooms, -> { where.not(code: nil) }
    scope :joinable, -> { rooms.unstarted.where(created_at: JOINABLE_FOR.ago..) }

    before_create :assign_code, if: -> { max_players > 1 }
  end

  class_methods do
    def open_for_join(code)
      joinable.find_by(code: code) || raise(NotFound)
    end
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
end
