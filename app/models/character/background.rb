class Character::Background < Data.define(:key, :label, :description)
  extend Catalog

  ALL = [
    new(key: "soldier", label: "Soldier", description: "Discipline, and the sight of war."),
    new(key: "criminal", label: "Criminal", description: "The lawless schooling of the streets."),
    new(key: "scholar", label: "Scholar", description: "Books and dead languages."),
    new(key: "noble", label: "Noble", description: "A name, standing, and expectations."),
    new(key: "traveler", label: "Traveler", description: "Far roads and other people's tables."),
    new(key: "artisan", label: "Artisan", description: "Skilled hands and patient work.")
  ].freeze
end
