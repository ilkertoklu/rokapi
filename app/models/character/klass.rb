class Character::Klass < Data.define(:key, :label, :description, :base_hp, :base_stats)
  ALL = [
    new(key: "warrior", label: "Savaşçı", description: "Ön safta dövüşür; uzun kılıç ve yuvarlak kalkanla başlar.",
        base_hp: 26, base_stats: { "strength" => 14, "agility" => 11, "constitution" => 13, "intelligence" => 8, "wisdom" => 12, "charisma" => 12 }.freeze),
    new(key: "ranger", label: "İzci", description: "İzi sürer, yayıyla uzaktan vurur; doğa onun evidir.",
        base_hp: 24, base_stats: { "strength" => 11, "agility" => 14, "constitution" => 12, "intelligence" => 10, "wisdom" => 14, "charisma" => 9 }.freeze),
    new(key: "rogue", label: "Hırsız", description: "Gölgede yürür; kilitler ve tuzaklar ona dert değil.",
        base_hp: 22, base_stats: { "strength" => 9, "agility" => 15, "constitution" => 10, "intelligence" => 12, "wisdom" => 11, "charisma" => 13 }.freeze),
    new(key: "mage", label: "Büyücü", description: "Eski sözlerin gücünü taşır; kırılgan ama yıkıcı.",
        base_hp: 18, base_stats: { "strength" => 8, "agility" => 10, "constitution" => 10, "intelligence" => 15, "wisdom" => 14, "charisma" => 13 }.freeze),
    new(key: "healer", label: "Şifacı", description: "Yoldaşlarını ayakta tutar; ışığı yanında taşır.",
        base_hp: 22, base_stats: { "strength" => 10, "agility" => 9, "constitution" => 13, "intelligence" => 12, "wisdom" => 15, "charisma" => 11 }.freeze),
    new(key: "bard", label: "Ozan", description: "Sözü silah gibi kullanır; moral ve kurnazlık onun işi.",
        base_hp: 20, base_stats: { "strength" => 9, "agility" => 12, "constitution" => 10, "intelligence" => 12, "wisdom" => 12, "charisma" => 15 }.freeze)
  ].freeze
  BY_KEY = ALL.index_by(&:key).freeze

  class << self
    def all = ALL
    def keys = BY_KEY.keys
    def [](key) = BY_KEY[key]
    def fetch(key) = BY_KEY.fetch(key)
    def base_stats_by_key = BY_KEY.transform_values(&:base_stats)
  end
end
