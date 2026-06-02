# Per-indicator coverage map for the analysis configurator's instant client-side validation: for each
# country, the years it has data, run-length encoded (contiguous years -> [from, to]). Tiny (~3 KB avg, 23 KB max;
# measured). The client fetches one map per indicator on select, then computes the exact balanced-country count for
# any [start, end] in pure JS - identical to PanelBuilder.n_countries (verified).
class IndicatorCoverage
  # { "BRA" => [[2000, 2022]], "POL" => [[1995, 2010], [2014, 2024]], ... }
  def self.for(indicator)
    Observation.where(indicator_id: indicator.id)
               .group(:country_iso3c)
               .pluck(Arel.sql("country_iso3c, array_agg(year ORDER BY year)"))
               .each_with_object({}) { |(iso, yrs), h| h[iso] = runs(coerce_years(yrs)) }
  end

  # pg returns int[] as a Ruby Array; guard the "{2000,2001}" string form too.
  def self.coerce_years(yrs)
    yrs.is_a?(String) ? yrs.tr("{}", "").split(",").map(&:to_i) : Array(yrs).map(&:to_i)
  end

  def self.runs(years)
    ys = years.uniq.sort
    return [] if ys.empty?
    out = []; s = ys.first; p = ys.first
    ys[1..].each { |y| (y == p + 1) ? (p = y) : (out << [s, p]; s = y; p = y) }
    out << [s, p]
    out
  end
end
