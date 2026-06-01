# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# WAVE 4 - map/viz libs via direct esm.sh (bawół  / : avoid bin/importmap pin → JSPM fan-out).
# deck.gl DEFERRED: brak pinów teraz; single UMD pin gdy 1. tryb flow/velocity.
# preload: false - heavy libs are dynamically imported in choropleth_controller#connect (lazy; non-map pages
# skip ~800KB). Preloading them defeats that AND warns "preloaded but not used" (still resolvable via the importmap).
pin "maplibre-gl", to: "https://esm.sh/maplibre-gl@5.24.0", preload: false
pin "chroma-js", to: "https://esm.sh/chroma-js@3.2.0", preload: false
# indicator search (Fuse.js, vanilla; dynamically imported in search_controller#open, lazy).
pin "fuse.js", to: "https://esm.sh/fuse.js@7.0.0", preload: false
