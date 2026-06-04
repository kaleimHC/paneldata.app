# Serves time-varying country-border map geometry from disk (GEO_DIR), built by `rake geo:borders`.
class GeoController < ApplicationController
  GEO_DIR = "/srv/paneldata/data/geo".freeze

  def show
    name = File.basename(params[:name].to_s) # defuse path traversal
    path = File.join(GEO_DIR, name)
    return head(:not_found) unless name.end_with?(".geojson") && File.file?(path)

    expires_in 12.hours, public: true
    send_file path, type: "application/geo+json", disposition: "inline"
  end
end
