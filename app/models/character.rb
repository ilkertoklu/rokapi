class Character < ApplicationRecord
  STATS = {
    "strength" => "Güç", "agility" => "Çeviklik", "constitution" => "Dayanıklılık",
    "intelligence" => "Zekâ", "wisdom" => "Sezgi", "charisma" => "Karizma"
  }.freeze
  STAT_KEYS = STATS.keys.freeze
  FREE_POINTS = 6
  STAT_CAP = 18

  belongs_to :player

  normalizes :stats, with: ->(stats) { stats.to_h.transform_values(&:to_i) }

  validates :race, inclusion: { in: Race.keys }
  validates :klass, inclusion: { in: Klass.keys }
  validates :background, inclusion: { in: Background.keys }
  validate :stats_match_allocation

  before_validation :derive_hp, on: :create

  def self.base_stats_for(klass)
    Klass.fetch(klass).base_stats
  end

  def summary
    [ Race.fetch(race).label, Klass.fetch(klass).label, Background.fetch(background).label ].join(" · ")
  end

  private
    def stats_match_allocation
      archetype = Klass[klass]
      return if archetype.nil?

      base = archetype.base_stats
      values = STAT_KEYS.index_with { |key| stats.to_h[key].to_i }
      out_of_range = values.any? { |key, value| value < base[key] || value > STAT_CAP }
      misallocated = values.values.sum != base.values.sum + FREE_POINTS

      errors.add :stats, :invalid if out_of_range || misallocated
    end

    def derive_hp
      archetype = Klass[klass]
      return if archetype.nil? || stats.blank?

      self.max_hp = archetype.base_hp + (stats["constitution"].to_i - 10)
      self.hp = max_hp
    end
end
