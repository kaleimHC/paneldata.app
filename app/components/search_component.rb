# INDICATOR SEARCH: a mouse-only search overlay (NOT a command palette - it only finds indicators). Trigger
# lives between the Explore/Analysis tabs. Fuse.js fuzzy search runs client-side over the catalog already embedded
# in the page (read from the picker's attribute - no extra copy, no backend). Selecting a result drives the active
# picker via openOn so the cascade fields are set to where the indicator lives. Visuals are intentionally minimal.
class SearchComponent < ViewComponent::Base
  def scope_labels     = %w[global regional national].index_with { |k| t("indicators.scope.#{k}") }
  def dziedzina_labels = IndicatorTaxonomy::DZIEDZINA_KEYS.index_with { |k| t("indicators.dziedzina.#{k}") }

  # Overlay header per trigger: each picker's magnifier opens the SAME overlay but sets which field it
  # targets, so the header names the field being set. Keyed by the picker id (map / analysis-predictor / -response).
  def target_titles = %w[map analysis-predictor analysis-response].index_with { |k| t("search.target.#{k}") }
end
