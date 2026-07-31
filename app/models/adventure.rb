class Adventure < ApplicationRecord
  has_many :game_sessions, dependent: :nullify

  validates :title, :hook, :brief, presence: true
end
