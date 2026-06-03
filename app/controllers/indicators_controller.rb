# Indicator coverage map for the configurator's instant client-side validation. Locale-independent JSON,
# fetched lazily on indicator select; the slider then computes the balanced-country count in pure JS.
class IndicatorsController < ApplicationController
  def coverage
    ind = Indicator.find_by(code: params[:code].to_s)
    return head(:not_found) unless ind

    render json: IndicatorCoverage.for(ind)
  end
end
