module GameSession::Rematchable
  extend ActiveSupport::Concern

  included do
    belongs_to :rematch_of, class_name: "GameSession", optional: true
    has_one :rematch, class_name: "GameSession", foreign_key: :rematch_of_id, inverse_of: :rematch_of

    after_create_commit -> { rematch_of.broadcast_refresh }, if: :rematch_of
  end

  def rematchable?
    multiplayer? && finished?
  end

  def start_rematch(by:)
    with_lock do
      rematch || create_rematch!(creator: by, surprise: surprise, tone: tone, length: length, locale: locale, max_players: max_players).tap do |room|
        party.reject(&:departed?).each { |player| room.players.create!(user: player.user) unless player.user == by }
      end
    end
  end
end
