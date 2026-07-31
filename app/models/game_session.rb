class GameSession < ApplicationRecord
  TONES = { "fun" => "Eğlenceli", "balanced" => "Dengeli", "dark" => "Karanlık" }.freeze
  LENGTHS = { "short" => "Kısa", "medium" => "Orta", "long" => "Uzun" }.freeze

  belongs_to :adventure, optional: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :players, dependent: :destroy

  enum :mode, %w[solo multi].index_by(&:itself)
  enum :tone, TONES.keys.index_by(&:itself), default: "balanced"
  enum :length, LENGTHS.keys.index_by(&:itself), default: "medium"
  enum :state, %w[lobby playing finished].index_by(&:itself), default: "lobby"

  scope :ongoing, -> { where.not(state: :finished) }

  after_create -> { players.create!(user: creator, host: true) }

  def title
    adventure&.title || "Sürpriz macera"
  end

  def player_for(user)
    players.find_by(user: user)
  end

  def start_when_ready!
    update! state: :playing if lobby? && players.where(ready: false).none?
  end
end
