class Character::Background < Data.define(:key, :label, :description)
  extend Catalog

  ALL = [
    new(key: "soldier", label: "Asker", description: "Disiplin ve savaş görmüşlük."),
    new(key: "criminal", label: "Suçlu", description: "Sokakların kuralsız okulu."),
    new(key: "scholar", label: "Bilgin", description: "Kitaplar ve eski diller."),
    new(key: "noble", label: "Soylu", description: "Ad, itibar ve beklentiler."),
    new(key: "traveler", label: "Gezgin", description: "Uzak yollar, yabancı sofralar."),
    new(key: "artisan", label: "Zanaatkâr", description: "Usta eller, sabırlı iş.")
  ].freeze
end
