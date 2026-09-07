class Player < ApplicationRecord
  belongs_to :game_session
  belongs_to :user

  has_one :character, dependent: :destroy
  has_many :rolls, dependent: :delete_all

  def ready_up(character_attributes)
    transaction do
      create_character! character_attributes
      game_session.start_when_ready
    end
  end
end
