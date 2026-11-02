class Player < ApplicationRecord
  belongs_to :game_session
  belongs_to :user

  has_one :character, dependent: :destroy
  has_many :rolls, dependent: :delete_all

  scope :in_join_order, -> { order(:created_at, :id) }

  delegate :name, :initial, to: :user

  after_create_commit -> { broadcast_refresh_to game_session }

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
