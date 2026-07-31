class Character::Race < Data.define(:key, :label, :description)
  ALL = [
    new(key: "human", label: "İnsan", description: "Çok yönlü ve dengeli; her sınıfa kolay uyum sağlar."),
    new(key: "half_elf", label: "Yarı-elf", description: "İki dünyanın çocuğu; uyumlu ve sezgili."),
    new(key: "elf", label: "Elf", description: "Çevik ve keskin duyulu; ormanın sessiz adımı."),
    new(key: "dwarf", label: "Cüce", description: "Dayanıklı ve inatçı; taş kadar sağlam."),
    new(key: "halfling", label: "Buçukluk", description: "Küçük, kıvrak ve şanslı; gözden kolay kaçar."),
    new(key: "tiefling", label: "Tiefling", description: "Gizemli ve karizmatik; içinde eski bir ateş yanar.")
  ].freeze
  BY_KEY = ALL.index_by(&:key).freeze

  class << self
    def all = ALL
    def keys = BY_KEY.keys
    def [](key) = BY_KEY[key]
    def fetch(key) = BY_KEY.fetch(key)
  end
end
