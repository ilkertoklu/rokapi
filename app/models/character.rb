class Character < ApplicationRecord
  FREE_POINTS = 6
  STAT_CAP = 18

  belongs_to :player

  has_many :items, dependent: :delete_all
  has_many :status_effects, dependent: :delete_all

  delegate :game_session, :user, to: :player

  attribute :race, default: "human"
  attribute :klass, default: "warrior"
  attribute :background, default: "soldier"
  attribute :stats, default: -> { Klass.fetch("warrior").base_stats }

  normalizes :stats, with: ->(stats) { stats.to_h.transform_values(&:to_i) }

  validates :race, inclusion: { in: Race.keys }
  validates :klass, inclusion: { in: Klass.keys }
  validates :background, inclusion: { in: Background.keys }
  validate :stats_match_allocation

  before_validation :derive_hp, on: :create
  after_create :grant_starting_gear

  def summary
    [ Race.fetch(race).label, Klass.fetch(klass).label, Background.fetch(background).label ].join(" · ")
  end

  def bonus_for(stat_key)
    (stats.fetch(stat_key) - 10) / 2
  end

  def hp_percentage
    (hp * 100.0 / max_hp).round
  end

  def adjust_hp(delta)
    before = hp
    update! hp: (hp + delta).clamp(0, max_hp) unless delta.zero?
    hp - before
  end

  def sturdy?
    hp_percentage > 60
  end

  def wounded?
    hp.positive? && hp_percentage <= 33
  end

  def status_modifier
    status_effects.sum(:modifier)
  end

  def lose_item(name)
    items.carried.find_by(name: name)&.delete
  end

  def gain_status(name:, **attributes)
    status_effects.where(name: name).delete_all
    status_effects.create! name: name, **attributes
  end

  def lose_status(name)
    status_effects.where(name: name).delete_all
  end

  private
    def stats_match_allocation
      return unless (base = Klass[klass]&.base_stats)

      values = Stat.keys.index_with { |key| stats.to_h[key].to_i }
      out_of_range = values.any? { |key, value| value < base[key] || value > STAT_CAP }
      misallocated = values.values.sum != base.values.sum + FREE_POINTS

      errors.add :stats, :invalid if out_of_range || misallocated
    end

    def derive_hp
      return unless stats.present? && (chosen = Klass[klass])

      self.max_hp = chosen.base_hp + (stats["constitution"].to_i - 10)
      self.hp = max_hp
    end

    def grant_starting_gear
      Klass.fetch(klass).gear.each { |piece| items.create! piece }
    end
end
