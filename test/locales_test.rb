require "test_helper"

class LocalesTest < ActiveSupport::TestCase
  CATALOGS = {
    Character::Race => %i[ label description ],
    Character::Klass => %i[ label description ],
    Character::Background => %i[ label description ],
    Character::Stat => %i[ label abbreviation ],
    GameSession::Tone => %i[ label ],
    GameSession::Length => %i[ label estimate ],
    GameSession::Quest => %i[ title hook brief ]
  }

  test "every key is translated into every language" do
    I18n.available_locales.each do |locale|
      keys_in(locale).each do |key|
        (I18n.available_locales - [ locale ]).each do |other|
          assert I18n.exists?(key, other), "#{key} is in #{locale}.yml but missing from #{other}"
        end
      end
    end
  end

  test "every catalog entry is named in every language" do
    CATALOGS.each do |catalog, attributes|
      catalog.all.product(attributes, I18n.available_locales).each do |entry, attribute, locale|
        assert_nothing_raised { entry.public_send(attribute, locale: locale, raise: true) }
      end
    end

    Character::Klass.all.flat_map(&:gear).product(I18n.available_locales).each do |piece, locale|
      assert I18n.exists?("character.gear.#{piece[:key]}.name", locale), "#{piece[:key]} has no #{locale} name"
    end
  end

  private
    def keys_in(locale)
      flatten YAML.load_file(Rails.root.join("config/locales/#{locale}.yml")).fetch(locale.to_s)
    end

    def flatten(translations, prefix = nil)
      translations.flat_map do |key, value|
        path = [ prefix, key ].compact.join(".")
        value.is_a?(Hash) ? flatten(value, path) : path
      end
    end
end
