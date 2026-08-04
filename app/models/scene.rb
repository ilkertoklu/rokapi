class Scene < ApplicationRecord
  class OutOfTurn < StandardError; end

  UNWRITTEN_STATES = %w[narrating failed].freeze

  belongs_to :game_session, touch: true
  belongs_to :active_player, class_name: "Player"

  has_many :choices, dependent: :destroy

  enum :state, %w[narrating choosing rolling played failed].index_by(&:itself), default: "narrating"

  scope :chronological, -> { order(:position) }
  scope :written, -> { where.not(state: UNWRITTEN_STATES) }
  scope :unwritten, -> { where(state: UNWRITTEN_STATES) }

  after_create_commit -> { game_session.broadcast_stage }
  after_update_commit -> { game_session.broadcast_stage }

  def broadcast_narration(text)
    broadcast_append_to game_session, target: :scene_narration, html: ERB::Util.html_escape(text)
  end

  def chosen_choice
    choices.detect(&:chosen?)
  end

  def roll
    chosen_choice&.roll
  end

  def roll!(by:)
    raise OutOfTurn unless rolling?

    chosen_choice.roll!(by: by)
  end

  def counter
    "#{position}. durak"
  end
end
