class Choice < ApplicationRecord
  belongs_to :scene

  has_one :roll, dependent: :destroy

  scope :chosen, -> { where.not(chosen_at: nil) }

  def stat_value
    scene.active_player.character.stats.fetch(stat)
  end

  def chosen?
    chosen_at.present?
  end

  def choose!
    transaction do
      raise Scene::OutOfTurn unless scene.choosing?

      update! chosen_at: Time.current
      scene.rolling!
    end
  end

  def roll!(by:)
    transaction do
      raise Scene::OutOfTurn unless scene.rolling? && chosen?

      scene.played!

      value = rand(1..Roll::DIE)
      create_roll!(
        player: by,
        value: value,
        modifier: modifier,
        target: difficulty,
        success: value + modifier >= difficulty
      )
    end
  end
end
