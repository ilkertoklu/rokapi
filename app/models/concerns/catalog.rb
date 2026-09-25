module Catalog
  def all = self::ALL
  def keys = by_key.keys
  def [](key) = by_key[key]
  def fetch(key) = by_key.fetch(key)

  def translates(*attributes)
    scope = name.underscore.tr("/", ".")

    attributes.each do |attribute|
      define_method(attribute) { |**options| I18n.t(attribute, scope: [ scope, key ], **options) }
    end
  end

  private
    def by_key = @by_key ||= all.index_by(&:key).freeze
end
