class Player < ApplicationRecord
  belongs_to :game_session
  belongs_to :user

  has_one :character, dependent: :destroy
  has_many :rolls, dependent: :destroy

  delegate :initial, to: :user

  def ready_up(character_attributes)
    transaction do
      create_character! character_attributes
      update! ready: true
      game_session.start_when_ready
    end
  end
end
