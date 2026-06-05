# MapLibre fill-layer choropleth. Rendered as the "Coverage map" block; mechanics in
# choropleth_controller.js (do not touch). Aspect-ratio box = world proportion (whole globe, no cropping).
class ChoroplethComponent < ViewComponent::Base
  def initialize(indicator_code:, year:)
    @indicator_code = indicator_code
    @year = year
  end

  def indicator
    @indicator ||= Indicator.find_by(code: @indicator_code)
  end

  # Versioned URL for the borders geojson so browsers auto-refetch when the geometry is rebuilt.
  # The asset is served from /srv with a long cache; ?v=mtime busts it per rebuild (immutable-version pattern).
  def geojson_url
    v = begin
      File.mtime("/srv/paneldata/data/geo/world-cshapes-gw.geojson").to_i
    rescue StandardError
      nil
    end
    v ? "/geo/world-cshapes-gw.geojson?v=#{v}" : "/geo/world-cshapes-gw.geojson"
  end
end
