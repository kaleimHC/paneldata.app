import { Controller } from "@hotwired/stimulus"

// MapLibre choropleth map-tool. Heavy libs (maplibre-gl ~800KB,
// chroma-js) dynamically imported in connect so non-map pages don't pay the cost (LCP target).
// Country key = ISO_A3_EH (Natural Earth ISO-corrected; matches our countries.iso3c 214/217 - ).
//
// Map-tool wiring (SPRAWA 4): indicator selection arrives as a window CustomEvent (indicator:selected)
// from indicator_browser_controller - decoupled, no shared global. Adds legend + hover tooltip + state header.

// Web-mercator normalized Y in [0,1] (0 at +~85°, 1 at -~85°) - used by the map's transformConstrain hard wall.
const mercatorY = (lat) => (1 - Math.log(Math.tan(Math.PI / 4 + (lat * Math.PI) / 360)) / Math.PI) / 2
const inverseMercatorY = (y) => (Math.atan(Math.exp((1 - 2 * y) * Math.PI)) - Math.PI / 4) * 360 / Math.PI

export default class extends Controller {
  static values = {
    indicatorCode: String,
    year: Number,
    geojsonUrl: { type: String, default: "/geo/world-cshapes-gw.geojson" }
  }
  static targets = ["map", "yearSlider", "yearMin", "yearMax", "legend", "indicatorLabel", "yearHeading"]

  ISO_KEY = "ISO_A3_EH"
  MISSING_COLOR = "#e5e7eb"
  WORLD_BOUNDS = [[-180, -56], [180, 84]]

  async connect() {
    if (!this.hasMapTarget) return
    const [{ default: maplibregl }, { default: chroma }] = await Promise.all([
      import("maplibre-gl"),
      import("chroma-js")
    ])
    this.maplibregl = maplibregl
    this.chroma = chroma
    this.currentObs = {}
    this.currentMeta = null
    this._onLocaleSwitch = () => {
      if (!this.hasIndicatorLabelTarget) return
      const catalog = document.querySelector("[data-indicator-catalog]")
      if (!catalog || !this.indicatorCodeValue) return
      try {
        const entry = JSON.parse(catalog.textContent).find(e => e.code === this.indicatorCodeValue)
        if (entry?.name) this.indicatorLabelTarget.textContent = entry.name
      } catch (_) {}
    }
    document.addEventListener("turbo:load", this._onLocaleSwitch)
    this.initializeMap()
  }

  initializeMap() {
    const [[WEST, SOUTH], [EAST, NORTH]] = this.WORLD_BOUNDS
    const maplibregl = this.maplibregl
    // HARD WALL via MapLibre's native transform constrain hook (transformConstrain, 5.24.0). Called AS A METHOD on
    // the transform (this === transform) during construction AND every camera change, BEFORE render → the viewport
    // can never spill past WORLD_BOUNDS and there is no overshoot/jitter (unlike a reactive moveend/move clamp,
    // which the maintainers document as janky; that whole approach is superseded). Reads viewport size from `this`
    // (the transform), NOT this.map (still undefined while it first runs). It also clamps zoom to [minZoom, maxZoom]
    // (the override bypasses the default zoom clamp); minZoom is locked to the world-fit in _refitWorld → no zoom-out
    // past the default whole-world view. Replaces the crashing native maxBounds path (§5a).
    const transformConstrain = function (lngLat, zoom) {
      // Clamp ZOOM too: overriding the default constrain also bypasses its min/max-zoom enforcement, so redo it here.
      // this.minZoom is locked to the world-fit in _refitWorld → the user can never zoom out past the default
      // whole-world view (the "center the shrunk world" fallback below then only matters as a safety net).
      const z = Math.min(Math.max(zoom, this.minZoom), this.maxZoom)
      const w = this.width, h = this.height
      if (!w || !h) return { center: lngLat, zoom: z }                       // not measured yet → pass through
      const ws = (this.tileSize || 512) * Math.pow(2, z)                     // world size in CSS px at this zoom
      const halfLng = (w / ws) * 180                                         // half visible lng span (deg, linear)
      const lng = halfLng >= (EAST - WEST) / 2 ? (WEST + EAST) / 2
                : Math.min(Math.max(lngLat.lng, WEST + halfLng), EAST - halfLng)
      const halfY = (h / ws) / 2                                             // half visible Y span (mercator [0,1])
      const yN = mercatorY(NORTH), yS = mercatorY(SOUTH)                     // yN < yS
      const y = (yS - yN <= 2 * halfY) ? (yN + yS) / 2
              : Math.min(Math.max(mercatorY(lngLat.lat), yN + halfY), yS - halfY)
      return { center: new maplibregl.LngLat(lng, inverseMercatorY(y)), zoom: z }
    }

    this.map = new this.maplibregl.Map({
      container: this.mapTarget,
      style: {
        version: 8,
        sources: {},
        // No background layer → the canvas is transparent; the ocean color comes from CSS background-color on the
        // map container (var(--map-bg)), so the large surface re-tints via CSS in lockstep with the page. WebGL can't
        // be pixel-locked to the CSS compositor (jitter ±1 frame), so the big surface stays out of WebGL.
        layers: []
      },
      center: [10, 25],
      zoom: 1,
      maxZoom: 6,
      renderWorldCopies: false,
      transformConstrain,             // ← native hard wall to WORLD_BOUNDS (smooth, pre-render)
      // Pan + zoom ON; rotate/pitch OFF. Pan is hard-walled by transformConstrain above; zoom is capped by
      // maxZoom (in) and the minZoom lock in _refitWorld (out) so the whole world always fits.
      dragPan: true,
      dragRotate: false,
      touchPitch: false,
      pitchWithRotate: false,
      attributionControl: false   // default sits bottom-right; add our own top-right below
    })
    // compact:true → MapLibre renders the attribution EXPANDED on load and natively tucks it back to the "ⓘ"
    // on first map drag. We also auto-collapse it after a few seconds with no interaction (the same op the lib
    // uses on drag: drop the compact-show class), so it reads on load then quietly gets out of the way.
    this.map.addControl(new this.maplibregl.AttributionControl({ compact: true }), "top-right")
    this._attribCollapseTimer = setTimeout(() => {
      const el = this.mapTarget.querySelector(".maplibregl-ctrl-top-right .maplibregl-ctrl-attrib.maplibregl-compact-show")
      if (el) el.classList.remove("maplibregl-compact-show")
    }, 8000)
    // Rotation off (keep pinch/scroll/dblclick zoom); keyboard rotate off (keep keyboard zoom/pan).
    this.map.touchZoomRotate.disableRotation()
    this.map.keyboard.disableRotation()
    this.map.on("load", () => this.loadWorldGeoJSON())

    // Insurance: re-fit when the container size settles/changes (sidebar drawer, theme, rotate, late layout).
    // Debounced - bare map.resize keeps the load-time zoom (→ dead-space/crop); _refitWorld re-fits the world.
    this.resizeObserver = new ResizeObserver(() => this._debouncedRefit())
    this.resizeObserver.observe(this.mapTarget)

  }

  // Re-fit the world to the current container size. Bare map.resize preserves center+zoom, so at any size other
  // than the one present at load the world is mis-fitted (empty band when larger, cropped when smaller). Relax
  // minZoom to the MapLibre hard floor (-2) BEFORE fitBounds so it can reach the true fit-zoom at any width
  // (mobile-portrait fit-zoom is < 0), then re-lock minZoom to it. Instant (duration:0) - this is the ONLY camera
  // move left (all user navigation is locked off in initializeMap); it just re-frames the world on container resize.
  _refitWorld() {
    if (!this.map) return
    this.map.resize()
    this.map.setMinZoom(-2)
    this.map.fitBounds(this.WORLD_BOUNDS, { padding: 6, duration: 0 })
    this.map.setMinZoom(this.map.getZoom())
  }

  // Own trailing-edge debounce (~150ms) - no lodash/node. Coalesces rapid resize/rotate bursts into one re-fit.
  _debouncedRefit() {
    clearTimeout(this._refitTimer)
    this._refitTimer = setTimeout(() => this._refitWorld(), 150)
  }

  async loadWorldGeoJSON() {
    const geojson = await (await fetch(this.geojsonUrlValue)).json()
    this.map.addSource("world", { type: "geojson", data: geojson, promoteId: this.ISO_KEY, attribution: "Borders: the borders dataset (Schvitz et al. 2022)" })
    this.map.addLayer({
      id: "world-fill",
      type: "fill",
      source: "world",
      // Antarctica excluded - Mercator bloats it, no country data; the layer filter drops ATA from render + hover.
      filter: ["!=", ["get", this.ISO_KEY], "ATA"],
      paint: { "fill-color": this.mapMissing(), "fill-outline-color": this.themeColor("--map-border", "#94a3b8") }
    })
    this.setupHoverTooltip()
    // Default view = populated world fitted to the (any-size) container. South -56 drops Antarctica from frame
    // (Cape Horn kept), north 84 ≈ Mercator limit. Re-run on EVERY resize/tab-show via _refitWorld (not just here)
    // so the world always fills the box - bare map.resize would keep the load-time zoom → dead-space/crop.
    this._refitWorld()
    // NOTE: maxBounds REMOVED - crashes constrainInternal (null) on resize in maplibre-gl 5.24.0 with
    // renderWorldCopies:false. renderWorldCopies:false alone already gives clean empty bg (no continent dupes);
    // minZoom-lock prevents zooming out past the globe. Pan-into-empty is acceptable (clean background).
    await this.fetchAndApplyData()
  }

  async fetchAndApplyData(allowClamp = true) {
    if (!this.map || !this.map.getLayer("world-fill")) return
    this.applyYearFilter() // time-varying borders: show only polygons valid for the current year
    const url = `/api/observations?indicator=${encodeURIComponent(this.indicatorCodeValue)}&year=${this.yearValue}`
    const data = await (await fetch(url)).json()
    const obs = data.observations || {}
    this.currentObs = obs
    this.currentMeta = data.indicator || null
    // Floor the slider at the borders dataset's start. Deep-history indicators
    // (Maddison from year 1, Polity from 1776) otherwise let the slider run into years the map cannot draw -
    // a blank globe. The pre-1886 data still exists; it just has no choropleth geometry to color.
    this.yearRange = data.year_range
    if (this.yearRange && this.yearRange[0] != null) this.yearRange[0] = Math.max(this.yearRange[0], 1886)
    this.updateYearSliderRange()

    const values = Object.values(obs)
    if (values.length === 0) {
      // Year-clamp: indicator switched and current year is outside its range → snap into range, retry once.
      if (allowClamp && this.yearRange && this.yearRange[0] != null) {
        const [lo, hi] = this.yearRange
        const clamped = Math.min(Math.max(this.yearValue, lo), hi)
        if (clamped !== this.yearValue) {
          this.yearValue = clamped
          if (this.hasYearSliderTarget) this.yearSliderTarget.value = clamped
          this.yearHeadingTargets.forEach((t) => { t.textContent = clamped })
          this.syncStateYear(clamped)
          return this.fetchAndApplyData(false)
        }
      }
      // Genuinely no data (e.g. prod before data load) - gray map, no legend.
      this.map.setPaintProperty("world-fill", "fill-color", this.mapMissing())
      this.renderLegend(null)
      this.dispatchLoaded(0)
      return
    }

    const min = Math.min(...values)
    const max = Math.max(...values)
    const isLog = data.indicator.transform_default === "log" && min > 0
    // Choropleth ramp = the active theme's --map-ramp-1..6 tokens: ONE sequential scale
    // per theme, used for BOTH directions (dark = high, always - a single reading convention). The indicator's
    // direction arrow carries polarity, so the hue no longer doubles it. Fallback = the old steel blue.
    const ramp = [1, 2, 3, 4, 5, 6].map((i) => this.themeColor(`--map-ramp-${i}`, null)).filter(Boolean)
    const scale = this.chroma.scale(ramp.length >= 2 ? ramp : ["#e8eef4", "#5b8bb5", "#1e3a5f"]).mode("lab")

    const norm = (v) => {
      if (max === min) return 0.5
      return isLog
        ? (Math.log(v) - Math.log(min)) / (Math.log(max) - Math.log(min))
        : (v - min) / (max - min)
    }

    const matchExpr = ["match", ["get", this.ISO_KEY]]
    for (const [iso3, value] of Object.entries(obs)) {
      matchExpr.push(iso3, scale(norm(value)).hex())
    }
    matchExpr.push(this.mapMissing())
    this.map.setPaintProperty("world-fill", "fill-color", matchExpr)

    this.renderLegend({ min, max, scale })
    this.dispatchLoaded(values.length)
  }

  // Broadcast load state for the sidebar metadata (Period/Coverage) - decoupled, no shared global.
  dispatchLoaded(count) {
    window.dispatchEvent(new CustomEvent("choropleth:loaded", {
      detail: { yearRange: this.yearRange, count }
    }))
  }

  // --- indicator selection (window CustomEvent from indicator_browser) ---
  indicatorSelected(event) {
    const { code, name } = event.detail || {}
    if (!code) return
    this.indicatorCodeValue = code
    if (name && this.hasIndicatorLabelTarget) this.indicatorLabelTarget.textContent = name
    this.fetchAndApplyData()
  }

  // Tab returned to Explore: container was display:none → MapLibre must re-measure or it renders empty (§5a).
  tabShown(event) {
    if (event.detail && event.detail.name === "explore" && this.map) {
      requestAnimationFrame(() => this._refitWorld())
    }
  }

  // Theme toggled - ocean is a CSS background (re-tints in lockstep). Outline + fills + no-data + legend all read
  // theme tokens now, so re-apply: outline directly, the rest via fetchAndApplyData (rebuilds the ramp from
  // --map-ramp-* and no-data from --map-missing). WebGL fills lag the CSS ~1 frame - imperceptible on a swap.
  themeChanged() {
    if (!this.map || !this.map.getLayer("world-fill")) return
    this.map.setPaintProperty("world-fill", "fill-outline-color", this.themeColor("--map-border", "#94a3b8"))
    this.fetchAndApplyData() // re-tint country fills + no-data + legend from the new theme's ramp/missing tokens
  }

  // --- year slider ---
  yearChanged(event) {
    this.yearValue = parseInt(event.target.value, 10)
    this.yearHeadingTargets.forEach((t) => { t.textContent = this.yearValue })
    this.syncStateYear(this.yearValue)
    this.fetchAndApplyData()
  }

  // Mirror the year into the Explore H1 (#state-year) - outside this controller's subtree, so by id (UI only).
  syncStateYear(y) {
    const el = document.getElementById("state-year")
    if (el) el.textContent = y
  }

  updateYearSliderRange() {
    if (!this.yearRange || this.yearRange[0] == null || !this.hasYearSliderTarget) return
    const [lo, hi] = this.yearRange
    this.yearSliderTarget.min = lo
    this.yearSliderTarget.max = hi
    this.yearMinTargets.forEach((t) => { t.textContent = lo })
    this.yearMaxTargets.forEach((t) => { t.textContent = hi })
  }

  // Time-varying borders: show only state-period polygons whose [start_year, end_year]
  // contains the current year. the borders dataset ends 2019, so years beyond show 2019 borders. ATA stays excluded.
  applyYearFilter() {
    if (!this.map || !this.map.getLayer("world-fill")) return
    const gy = Math.min(this.yearValue, 2019)
    this.map.setFilter("world-fill", ["all",
      ["!=", ["get", this.ISO_KEY], "ATA"],
      ["<=", ["get", "start_year"], gy],
      [">=", ["get", "end_year"], gy]])
  }

  // --- legend ---
  renderLegend(info) {
    if (!this.hasLegendTarget) return
    if (!info) { this.legendTarget.style.display = "none"; return }
    const { min, max, scale } = info
    const unit = this.currentMeta && this.currentMeta.unit ? this.currentMeta.unit : ""
    const gradient = scale.colors(6).join(", ")
    // Compact horizontal scale for the card header (a4): [unit] min ▬gradient▬ max - inline, no map overlay.
    this.legendTarget.innerHTML = `
      ${unit ? `<span class="text-ink-muted">${unit}</span>` : ""}
      <span style="font-variant-numeric:tabular-nums">${this.formatValue(min, false)}</span>
      <span style="display:inline-block;height:6px;width:84px;border-radius:9999px;background:linear-gradient(to right, ${gradient})"></span>
      <span style="font-variant-numeric:tabular-nums">${this.formatValue(max, false)}</span>`
    this.legendTarget.style.display = "flex"
  }

  // --- hover tooltip (country + value; missing = "brak danych", never NULL - ) ---
  setupHoverTooltip() {
    this.popup = new this.maplibregl.Popup({ closeButton: false, closeOnClick: false, offset: 8 })
    this.map.on("mousemove", "world-fill", (e) => this.showTooltip(e))
    this.map.on("mouseleave", "world-fill", () => {
      this.map.getCanvas().style.cursor = ""
      if (this.popup) this.popup.remove()
    })
  }

  showTooltip(e) {
    const f = e.features && e.features[0]
    if (!f) return
    this.map.getCanvas().style.cursor = "pointer"
    const iso = f.properties[this.ISO_KEY]
    // Localized country name via the platform i18n facility (Intl.DisplayNames), read at the CURRENT page
    // locale so it tracks language switches even though the map node is turbo-permanent. Falls back to the
    // GeoJSON name for historical/unmapped entities (no ISO-2).
    // Historical period names (e.g. Soviet Union for the 1921-1991 RUS polygons) override the ISO->DisplayNames
    // name, which would otherwise collapse every period of an ISO into the modern country (always "Russia").
    const name = this.histName(f.properties.name) || this.localizedName(f.properties.iso2) || f.properties.name || iso || "-"
    const v = this.currentObs ? this.currentObs[iso] : undefined
    const noData = document.querySelector('meta[name="map-no-data"]')?.content || "no data"
    const valStr = (v === undefined || v === null) ? noData : this.formatValue(v)
    this.popup.setLngLat(e.lngLat)
      .setHTML(`<strong>${name}</strong><br>${valStr}`)
      .addTo(this.map)
  }

  formatValue(v, withUnit = true) {
    const n = Number(v)
    const digits = Math.abs(n) >= 1000 ? 0 : 2
    const s = n.toLocaleString(document.documentElement.lang || "en", { maximumFractionDigits: digits })
    const unit = this.currentMeta && this.currentMeta.unit ? this.currentMeta.unit : ""
    return withUnit && unit ? `${s} ${unit}` : s
  }

  // Localized name for a historical map entity, keyed by its GeoJSON `name`. Source is the i18n-rendered
  // map-hist-names meta (re-rendered per navigation), so it tracks the page locale even though the map node is
  // turbo-permanent. Parsed lazily and re-parsed only when the meta content changes (locale switch).
  histName(rawName) {
    if (!rawName) return null
    const content = document.querySelector('meta[name="map-hist-names"]')?.content || "{}"
    if (this._histRaw !== content) {
      try { this._hist = JSON.parse(content) } catch (_) { this._hist = {} }
      this._histRaw = content
    }
    return this._hist[rawName] || null
  }

  // Localized country name from an ISO-2 code at the current page locale (cached per locale).
  localizedName(iso2) {
    if (!iso2) return null
    const lang = document.documentElement.lang || "en"
    try {
      this._regionNames ||= {}
      this._regionNames[lang] ||= new Intl.DisplayNames([lang], { type: "region" })
      return this._regionNames[lang].of(iso2)
    } catch (_) {
      return null
    }
  }

  themeColor(varName, fallback) {
    const v = getComputedStyle(document.documentElement).getPropertyValue(varName).trim()
    return v || fallback
  }

  // No-data country fill = the active theme's --map-missing token (fallback = the old light grey). Re-tints per
  // theme so missing countries are no longer a light-grey blob on a dark ocean.
  mapMissing() { return this.themeColor("--map-missing", this.MISSING_COLOR) }

  disconnect() {
    clearTimeout(this._refitTimer)
    clearTimeout(this._attribCollapseTimer)
    if (this.resizeObserver) this.resizeObserver.disconnect()
    if (this.popup) this.popup.remove()
    if (this.map) this.map.remove()
    if (this._onLocaleSwitch) document.removeEventListener("turbo:load", this._onLocaleSwitch)
  }
}
