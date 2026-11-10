class Plan < Data.define(:key, :scenes)
  extend Catalog

  STORE_PRODUCTS = Rails.application.config_for(:store_products)

  translates :name, :adventures, :perk

  ALL = [
    new(key: "free", scenes: 10),
    new(key: "standard", scenes: 60),
    new(key: "premium", scenes: 180),
    new(key: "max", scenes: 450)
  ].freeze

  def self.free
    fetch("free")
  end

  def self.paid
    all.excluding(free)
  end

  def self.for_store_product(store_product_id)
    paid.find { |plan| plan.store_product_ids.include?(store_product_id) } || raise(KeyError, "No plan sells #{store_product_id}")
  end

  def popular?
    key == "premium"
  end

  def store_product
    PurchaseKit::Product.find(STORE_PRODUCTS.dig(key.to_sym, :purchasekit))
  end

  def store_product_ids
    STORE_PRODUCTS.fetch(key.to_sym).values_at(:apple, :google)
  end
end
