class Scene < ApplicationRecord
  class OutOfTurn < StandardError; end

  belongs_to :game_session, touch: true
  belongs_to :active_player, class_name: "Player"

  has_many :choices, dependent: :destroy
  has_one :chosen_choice, -> { chosen }, class_name: "Choice"
  has_one :roll, through: :chosen_choice

  enum :state, %w[narrating choosing rolling played].index_by(&:itself), default: "narrating"

  scope :chronological, -> { order(:position) }

  after_save_commit -> { broadcast_refresh_to game_session }

  def broadcast_narration(text)
    broadcast_append_to game_session, target: :scene_narration, html: ERB::Util.html_escape(text)
  end

  def stalled?
    stalled_at.present?
  end

  def narrator_writing?
    (narrating? || played?) && !stalled?
  end

  def stall_narration
    update! stalled_at: Time.current
  end

  def resume_narration
    update! stalled_at: nil
    game_session.continue_narration_later
  end

  def roll_dice(by:)
    transaction do
      raise OutOfTurn unless rolling?

      played!
      chosen_choice.roll_dice(by: by)
    end
  end

  def counter
    "#{position}. durak"
  end
end
