module Api
  class ObservationsController < ApplicationController
    # GET /api/observations?indicator=<code>&year=<int>
    # → { indicator: {...}, year:, observations: { iso3c => float }, year_range: [min,max] }
    # Choropleth fill data. Real countries only (entity_type='country', ) - aggregates excluded.
    def index
      indicator = Indicator.find_by!(code: params[:indicator])
      year = params[:year].to_i

      observations = Observation
        .joins(:country)
        .where(indicator_id: indicator.id, year: year)
        .where(countries: { entity_type: "country" })
        .pluck("countries.iso3c", :value)
        .to_h
        .transform_values(&:to_f)

      indicator_obs = Observation.where(indicator_id: indicator.id)
      year_range = [indicator_obs.minimum(:year), indicator_obs.maximum(:year)]

      render json: {
        indicator: {
          code: indicator.code,
          name: indicator.display_name,
          unit: indicator.unit,
          transform_default: indicator.transform_default,
          direction: indicator.direction
        },
        year: year,
        observations: observations,
        year_range: year_range
      }
    end
  end
end
