class ApplicationController < ActionController::Base
  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # i18n: resolve locale per request (URL → cookie → Accept-Language → default EN), thread-safe via around.
  around_action :switch_locale

  private

  def switch_locale(&action)
    locale = resolve_locale
    cookies.permanent[:locale] = locale if params[:locale].present?
    I18n.with_locale(locale, &action)
  end

  def resolve_locale
    candidate = params[:locale] || cookies[:locale] || locale_from_accept_language
    available = I18n.available_locales.map(&:to_s)
    available.include?(candidate.to_s) ? candidate : I18n.default_locale
  end

  # First Accept-Language tag that we actually support (e.g. "pl-PL,en;q=0.8" → :pl).
  def locale_from_accept_language
    header = request.env["HTTP_ACCEPT_LANGUAGE"]
    return nil if header.blank?

    available = I18n.available_locales.map(&:to_s)
    header.scan(/[a-z]{2}/i).map(&:downcase).find { |tag| available.include?(tag) }
  end

  # Keep the active locale in every generated URL (count-agnostic; switcher/links carry it).
  def default_url_options
    { locale: I18n.locale }
  end
end
