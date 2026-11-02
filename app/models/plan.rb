class Plan < Data.define(:key, :scenes)
  extend Catalog

  translates :name, :adventures

  ALL = [
    new(key: "free", scenes: 10),
    new(key: "standard", scenes: 60),
    new(key: "premium", scenes: 180),
    new(key: "max", scenes: 450)
  ].freeze
end
