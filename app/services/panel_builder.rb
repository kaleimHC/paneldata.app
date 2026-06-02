require "csv"

# Builds a balanced panel CSV (iso3c, year, response, predictor) for the PVAR worker. Response & predictor
# series come from `observations`. "Balanced" = a country must have BOTH series for EVERY year in [start, end];
# partial countries are dropped (inner join + balance, matching FINAL_STANDALONE.R).
class PanelBuilder
  Result = Struct.new(:csv_path, :n_countries, :n_years, :rows, keyword_init: true)

  def self.build(response_indicator:, predictor_indicator:, start_year:, end_year:, out_path:)
    resp  = series_for(response_indicator, start_year, end_year)
    pred  = series_for(predictor_indicator, start_year, end_year)
    years = (start_year..end_year).to_a
    isos  = (resp.keys.map(&:first) & pred.keys.map(&:first)).uniq.sort

    written = 0
    CSV.open(out_path, "w") do |csv|
      csv << %w[iso3c year response predictor]
      isos.each do |iso|
        cells = years.map { |y| [resp[[iso, y]], pred[[iso, y]]] }
        next if cells.any? { |r, p| r.nil? || p.nil? }   # balanced only
        years.each_with_index { |y, i| csv << [iso, y, cells[i][0], cells[i][1]] }
        written += 1
      end
    end
    Result.new(csv_path: out_path, n_countries: written, n_years: years.size, rows: written * years.size)
  end

  def self.series_for(indicator, start_year, end_year)
    Observation.where(indicator_id: indicator.id, year: start_year..end_year)
               .pluck(:country_iso3c, :year, :value)
               .each_with_object({}) { |(iso, y, v), h| h[[iso, y]] = v.to_f }
  end
end
