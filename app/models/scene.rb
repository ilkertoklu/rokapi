class Scene < ApplicationRecord
  class OutOfTurn < StandardError; end

  include Stallable

  belongs_to :game_session, touch: true
  belongs_to :active_player, class_name: "Player"

  has_many :choices, dependent: :destroy
  has_one :chosen_choice, -> { chosen }, class_name: "Choice"
  has_one :roll, through: :chosen_choice

  enum :state, %w[narrating choosing rolling played].index_by(&:itself), default: "narrating"

  scope :chronological, -> { order(:position) }

  after_save_commit -> { broadcast_refresh_to game_session }

  def broadcast_narration(text)
    broadcast_update_to game_session, target: :scene_narration, html: ERB::Util.html_escape(text)
  end

  def first?
    position == 1
  end

  def opening?
    first? && title.nil?
  end

  def narrator_writing?
    narrating? && !stalled?
  end

  def narrate
    Narrator.new(game_session).narrate_scene(self)
  end

  def narrate_later
    Scene::NarrateJob.perform_later self
  end

  def roll_dice(by:)
    transaction do
      raise OutOfTurn unless rolling?

      played!
      chosen_choice.roll_dice(by: by)
    end
  end

  def counter
    "Stop #{position}"
  end
end
