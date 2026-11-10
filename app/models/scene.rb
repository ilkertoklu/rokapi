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

  def write(narration:, effects:)
    transaction do
      game_session.update! title: effects["adventure"] if first? && effects["adventure"].present?
      update! narration: narration, effects: recorded(effects.to_h), title: effects["title"].presence, location: effects["location"].presence,
        state: :choosing, stalled_at: nil
      apply_effects
      Array(effects["choices"]).each { |choice| offer choice }
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

  def companions
    game_session.party.select { !turn_of?(it) && it.standing? }
  end

  def first?
    position == 1
  end

  def last?
    position >= game_session.scene_budget
  end

  def clue_overdue?
    !first? && !last? && game_session.clues_left >= game_session.scene_budget - position
  end

  def conclude(outcome)
    update! finale: true
    game_session.update! outcome: outcome
    game_session.finish
  end

  def part_of_the_story
    middle = (game_session.scene_budget + 1) / 2.0

    if last?
      "the story's last scene"
    elsif position < middle.floor
      "the story's first half"
    elsif position > middle.ceil
      "the story's second half"
    else
      "the middle of the story"
    end
  end

  def closing
    roll&.resolution || narration
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
    def offer(choice)
      choices.create! label: choice["label"], stat: choice["stat"], modifier: character.bonus_for(choice["stat"]), target: Choice.target_for(choice["difficulty"])
    end

    def recorded(effects)
      bounded(effects).merge({ "clue" => clue_shown }.compact)
    end

    def clue_shown
      game_session.next_clue if clue_overdue?
    end

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
