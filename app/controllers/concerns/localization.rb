module Localization
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
  end

  private
    def switch_locale(&action)
      I18n.with_locale(requested_locale || I18n.default_locale, &action)
    end

    def requested_locale
      [ cookies[:locale], *browser_locales ].find { |locale| I18n.locale_available?(locale) }
    end

    def browser_locales
      request.headers["Accept-Language"].to_s.split(",").filter_map { |range| range[/\A\s*([a-z]{2})\b/i, 1]&.downcase }
    end
end
