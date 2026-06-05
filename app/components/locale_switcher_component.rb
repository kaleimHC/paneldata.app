# Top-bar locale switcher. Server-side: links to the current page in each available locale.
# Count-agnostic - iterates I18n.available_locales, so adding a language needs no change here.
class LocaleSwitcherComponent < ViewComponent::Base
  def locales = I18n.available_locales

  def current?(locale) = locale == I18n.locale
end
