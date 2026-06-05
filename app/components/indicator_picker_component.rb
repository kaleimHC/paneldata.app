# INDICATOR PICKER: the shared 4-axis select fields used in BOTH the map sidebar and the analysis config.
# Pokrycie -> (conditional Region/Country) -> Dziedzina -> Wskaznik, with the indicator list grouped by
# Wydawca - Kolekcja. All cascading filtering happens client-side in indicator_picker_controller over the catalog
# JSON. This is NOT a search box (that is a separate, later layer).
#
# mode:
#   :map      - every indicator selectable; dispatches indicator:selected to the choropleth; reads live
#               coverage/period from choropleth:loaded.
#   :analysis - the final Wskaznik <select> carries data-pvar-target="predictor" (pvar_controller reads it);
#               non-loggable indicators (value_min <= 0) are disabled, because the predictor goes through log.
class IndicatorPickerComponent < ViewComponent::Base
  # role (analysis only): :predictor (explanatory) or :response. Drives the pvar target name + the dispatched
  # event + the localStorage key, so the two identical analysis pickers don't collide.
  def initialize(mode:, selected_code: nil, role: :predictor)
    @mode = mode.to_sym
    @selected_code = selected_code
    @role = role.to_sym
  end
  attr_reader :mode, :selected_code, :role

  def analysis? = mode == :analysis

  def catalog
    @catalog ||= IndicatorCatalog.entries(include_loggable: analysis?)
  end

  # The indicator we open on: the explicit selected_code if present, else the first (loggable, for analysis) entry.
  def initial_code
    return selected_code if selected_code.present?
    pool = analysis? ? catalog.select { |e| e[:computable] } : catalog
    pool.first&.dig(:code)
  end

  def initial_entry = catalog.find { |e| e[:code] == initial_code }

  # Collection display: prepend the publisher when it fits one line - full publisher, else its acronym, else the
  # collection alone (mirrors collectionDisplay in the controller).
  COLLECTION_DISPLAY_MAX = 34
  def initial_collection_display
    e = initial_entry
    return "-" unless e
    coll = e[:collection].to_s
    fits = ->(p) { p.present? && p != coll && "#{p} - #{coll}".length <= COLLECTION_DISPLAY_MAX }
    full = e[:publisher].to_s.sub(/\s*\([^()]*\)\s*\z/, "").strip
    return "#{full} - #{coll}" if fits.call(full)
    acr = e[:publisher].to_s[/\(([A-Z][A-Z0-9.\-]{1,9})\)/, 1]
    return "#{acr} - #{coll}" if acr && fits.call(acr)
    short = e[:publisher_short]
    return "#{short} - #{coll}" if short && fits.call(short)
    coll.presence || "-"
  end

  # Provenance link (source/ranking page) shown in the description; host only, for a compact explicit label.
  def initial_link = initial_entry&.dig(:link)
  def initial_link_host
    return nil unless (l = initial_link)
    URI.parse(l).host rescue l
  end

  # Static option key lists (labels are i18n'd in the template).
  def scope_keys      = %w[global regional national]
  def dziedzina_keys  = IndicatorTaxonomy::DZIEDZINA_KEYS
end
