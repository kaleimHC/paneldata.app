# Flat indicator catalog for the pickers. One row per browsable indicator with the 4 taxonomy axes
# resolved, fed as JSON to indicator_picker_controller which does all the cascading filtering client-side.
# Built per request (display_name is locale-dependent). The browsable universe = indicators with observations
# on THIS env.
class IndicatorCatalog
  # include_loggable: true only for the analysis picker (predictor goes through log). Map omits it (no constraint).
  def self.entries(include_loggable: false)
    inds = Indicator.with_observations.where(is_active: true)
                    .includes(:data_source, :license_record).order(:name).to_a
    inds.map { |i| entry(i, include_loggable) }
  end

  def self.entry(ind, include_loggable)
    ds = ind.data_source
    code = ds&.code
    e = {
      code:       ind.code,
      name:       ind.display_name,
      publisher:  ds&.organization.presence || ind.source,
      publisher_short: IndicatorTaxonomy.publisher_short(code),
      collection: ds&.name.presence || ind.source,
      dziedzina:  IndicatorTaxonomy.dziedzina(ind.dimension),
      scope:      IndicatorTaxonomy.scope(code),
      region:     IndicatorTaxonomy.region(code),
      # license string cache is nil for non-SPDX licenses; fall back to the normalized record name
      # so "Custom (per-source)" / "All Rights Reserved" surface instead of a blank.
      license:     ind.license.presence || ind.license_record&.name,
      license_url: ind.license_record&.url,
      # Provenance link shown in the picker: the per-indicator source/ranking page, else the publisher homepage.
      link:        ind.methodology_url.presence || ds&.homepage_url.presence
    }
    if include_loggable
      e[:loggable]   = ind.loggable?    # value > 0 (predictor goes through log())
      e[:computable] = ind.computable?  # loggable AND licence allows derivatives (NoDerivatives -> map-only)
    end
    e
  end
end
