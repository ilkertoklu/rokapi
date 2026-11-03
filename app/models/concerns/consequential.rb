module Consequential
  extend ActiveSupport::Concern

  NO_EFFECTS = { "hp" => 0, "items_gained" => [], "items_lost" => [], "statuses_gained" => [], "statuses_lost" => [] }.freeze

  included do
    store_accessor :effects, :hp, suffix: :change
    store_accessor :effects, :items_gained, :items_lost, :statuses_gained, :statuses_lost

    normalizes :effects, with: ->(effects) { NO_EFFECTS.merge(effects.to_h.deep_stringify_keys) }
  end

  private
    def bounded(effects)
      statuses_lost = Array(effects["statuses_lost"])
      statuses_gained = granted(effects["statuses_gained"]).map { |grant| status_from(grant) }.select { |status| boon? || !status["modifier"].positive? }
      kept = character.status_effects.map(&:name) - statuses_lost - statuses_gained.pluck("name")

      { "hp" => effects["hp"].to_i.clamp(health_floor, 0),
        **carried(effects["carries"]),
        "statuses_gained" => statuses_gained.first([ StatusEffect::LIMIT - kept.size, 0 ].max),
        "statuses_lost" => statuses_lost }
    end

    def carried(carries)
      return { "items_gained" => [], "items_lost" => [] } if carries.nil?

      unlisted = character.items.carried.to_a
      gained, lost = [], []

      Array(carries).each do |entry|
        grant = entry.is_a?(Hash) ? entry : described(entry.to_s)
        next if grant["name"].blank?

        if (held = unlisted.find { |item| item.summary == entry || item.name == grant["name"] })
          unlisted.delete held
          next if held.instant? || held.summary == entry || grant["description"].blank? || grant["description"] == held.description

          lost << held.name
          gained << item_from(grant.merge("kind" => held.kind))
        else
          gained << item_from(grant)
        end
      end

      { "items_gained" => gained, "items_lost" => lost + unlisted.reject(&:instant?).map(&:name) }
    end

    def described(entry)
      name, description = entry.match(/\A(.+?)\s*(?:\((.*)\))?\z/m).captures
      { "name" => name.strip, "description" => description }
    end

    def granted(grants)
      Array(grants).grep(Hash).select { |grant| grant["name"].present? }
    end

    def item_from(grant)
      kind = Item.kinds.fetch(grant["kind"], "passive")
      instant = kind == "instant"

      { "name" => grant["name"], "kind" => kind, "description" => grant["description"],
        "hp_effect" => instant ? grant["hp"].to_i : 0,
        "uses_left" => ([ grant["uses"].to_i, Item::MINIMUM_USES ].max if instant) }
    end

    def status_from(grant)
      turns = grant["turns"].to_i
      expires_when = grant["expires_when"].presence

      { "name" => grant["name"], "modifier" => grant["modifier"].to_i.clamp(StatusEffect::MODIFIER_RANGE), "expires_when" => expires_when,
        "turns_left" => turns.positive? ? turns.clamp(StatusEffect::TURNS) : (StatusEffect::DEFAULT_TURNS if expires_when.nil?) }
    end

    def apply_effects
      character.adjust_hp hp_change

      items_lost.each { |name| character.lose_item name }
      items_gained.each { |item| character.items.create! item }
      statuses_lost.each { |name| character.lose_status name }
      statuses_gained.each { |status| character.gain_status(**status.symbolize_keys) }
    end
end
