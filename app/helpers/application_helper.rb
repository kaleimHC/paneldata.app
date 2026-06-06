module ApplicationHelper
  # URL of the current page in another locale (preserves route + query) - for the locale switcher.
  def switch_locale_url(locale)
    url_for(request.path_parameters.merge(request.query_parameters).merge(locale: locale))
  end

  # Absolute per-locale URLs of the current page - for <link rel="alternate" hreflang> SEO tags.
  # Count-agnostic: loops I18n.available_locales, so a new language needs no change here.
  def hreflang_alternates
    I18n.available_locales.map do |locale|
      [locale, url_for(request.path_parameters.merge(request.query_parameters).merge(locale: locale, only_path: false))]
    end
  end
end
