class Scene < ApplicationRecord
  class OutOfTurn < StandardError; end

  include Consequential, Stallable

  belongs_to :game_session, touch: true
  belongs_to :active_player, class_name: "Player"

  has_many :choices, dependent: :destroy
  has_one :chosen_choice, -> { chosen }, class_name: "Choice"
  has_one :roll, through: :chosen_choice

  enum :state, %w[narrating choosing rolling played].index_by(&:itself), default: "narrating"

  scope :chronological, -> { order(:position) }

  after_save_commit -> { broadcast_refresh_to game_session }

  def write(narration:, effects:, **attributes)
    transaction do
      update! narration: narration, effects: bounded(effects.to_h), **attributes
      apply_effects
    end
  end

  def stream(prose)
    return if narration == prose

    self.narration = prose
    broadcast_narration
  end

  def broadcast_narration
    broadcast_update_to game_session, target: :scene_narration, partial: "scenes/narration"
  end

  def turn_of?(player)
    active_player == player
  end

  def first?
    position == 1
  end

  def last?
    position >= game_session.scene_budget
  end

  def followed_by_the_last?
    position + 1 >= game_session.scene_budget
  end

  def ending
    if active_player.character.hp.zero?
      "defeat"
    elsif last?
      game_session.verdict
    end
  end

  def opening?
    first? && narrating?
  end

  def narrator_writing?
    narrating? && !stalled?
  end

  def narrate
    Narrator.for(game_session).narrate_scene(self)
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
    I18n.t("scene.counter", position: position, total: game_session.scene_budget)
  end

  private
    def character
      active_player.character
    end

    def health_floor
      0
    end

    def boon?
      false
    end
end
