class Narrator::Resolution
  attr_reader :text, :effects

  def initialize(roll, data)
    raise Narrator::MalformedResponse, "structured output missing" unless data.is_a?(Hash)

    @roll = roll
    @text = Narrator::Screen.fit("the resolution", data["resolution"].presence || raise(Narrator::MalformedResponse, "resolution missing"), Narrator::Screen::RESOLUTION_WORDS)
    @effects = effects_in(data["effects"].to_h)
  end

  private
    def effects_in(effects)
      statuses_lost = Array(effects["statuses_lost"])
      statuses_gained = earned(Array(effects["statuses_gained"]).map { |grant| status_in(grant) })
      within_status_limit statuses_gained, statuses_lost

      { "hp" => effects["hp"].to_i.clamp(Roll::HEALTH_FLOOR.fetch(@roll.grade, 0), 0),
        "items_gained" => Array(effects["items_gained"]).map { |grant| item_in(grant) },
        "items_lost" => Array(effects["items_lost"]),
        "statuses_gained" => statuses_gained,
        "statuses_lost" => statuses_lost }
    end

    def within_status_limit(gained, lost)
      kept = @roll.player.character.status_effects.map(&:name) - lost - gained.pluck(:name)
      return if gained.none? || kept.size + gained.size <= StatusEffect::LIMIT

      raise Narrator::MalformedResponse, "the character would carry #{kept.size + gained.size} statuses, at most #{StatusEffect::LIMIT}"
    end

    def earned(statuses)
      @roll.critical? ? statuses : statuses.reject { |status| status[:modifier].positive? }
    end

    def item_in(grant)
      kind = grant["kind"].presence_in(Item.kinds.keys) || raise(Narrator::MalformedResponse, "unknown item kind #{grant["kind"].inspect}")
      instant = kind == "instant"

      { name: name_in(grant), kind: kind, description: grant["description"],
        hp_effect: instant ? grant["hp"].to_i : 0,
        uses_left: ([ grant["uses"].to_i, Item::MINIMUM_USES ].max if instant) }
    end

    def status_in(grant)
      turns = grant["turns"].to_i
      expires_when = grant["expires_when"].presence

      { name: name_in(grant), modifier: grant["modifier"].to_i.clamp(StatusEffect::MODIFIER_RANGE), expires_when: expires_when,
        turns_left: turns.positive? ? turns.clamp(StatusEffect::TURNS) : (StatusEffect::DEFAULT_TURNS if expires_when.nil?) }
    end

    def name_in(grant)
      grant["name"].presence || raise(Narrator::MalformedResponse, "nameless grant")
    end
end
