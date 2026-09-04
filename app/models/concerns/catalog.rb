module Catalog
  def all = self::ALL
  def keys = by_key.keys
  def [](key) = by_key[key]
  def fetch(key) = by_key.fetch(key)

  private
    def by_key = @by_key ||= all.index_by(&:key).freeze
end
