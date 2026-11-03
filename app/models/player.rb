class Player < ApplicationRecord
  belongs_to :game_session
  belongs_to :user, optional: true

  has_one :character, dependent: :destroy
  has_many :rolls, dependent: :delete_all

  scope :in_join_order, -> { order(:created_at, :id) }

  after_create_commit -> { broadcast_refresh_to game_session }

  def name
    user&.name || I18n.t("player.departed")
  end

  def initial
    user&.initial || "·"
  end

  def departed?
    user.nil?
  end

  def depart
    game_session.started? ? update!(user: nil) : destroy!
  end

  def attempts
    rolls.includes(:choice).order(:created_at).map { |roll| %("#{roll.choice.label}" (#{roll.success? ? "succeeded" : "failed"})) }
  end

  def ready?
    character.present?
  end

  def seat
    game_session.players.in_join_order.ids.index(id)
  end

  def ready_up(character_attributes)
    transaction do
      create_character! character_attributes
      game_session.start_when_ready
    end
  end
end
