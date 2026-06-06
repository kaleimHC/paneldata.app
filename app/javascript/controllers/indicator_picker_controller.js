import { Controller } from "@hotwired/stimulus"
import { durMs } from "controllers/motion"

// INDICATOR PICKER. Shared cascade select fields for both the map sidebar and the analysis config.
// Pokrycie -> (conditional Region/Country) -> Dziedzina -> Wydawca -> Wskaznik, indicator list grouped by Kolekcja.
// All cascading filtering is client-side over the catalog JSON. NOT a search box.
//   mode "map":      every indicator selectable; dispatches indicator:selected; reads choropleth:loaded.
//   mode "analysis": the Wskaznik <select> is the pvar predictor input; non-loggable (value_min<=0) disabled.
export default class extends Controller {
  static values = { mode: String, role: String, initial: String, regionLabels: Object, scopeLabels: Object,
                    dziedzinaLabels: Object, allDziedzina: String, allPublishers: String, pickPublisher: String }

  // Shared catalog: ONE <script data-indicator-catalog> in the page, read by every picker + search.
  get catalog() {
    if (!this._catalog) {
      const el = document.querySelector("[data-indicator-catalog]")
      try { this._catalog = el ? JSON.parse(el.textContent) : [] } catch (_) { this._catalog = [] }
    }
    return this._catalog
  }
  static targets = ["scope", "regionField", "region", "dziedzina", "publisher", "indicator", "legend",
                    "description", "metaCollection", "metaCoverage", "metaPeriod", "metaLicense", "metaLink"]

  connect() {
    this._count = null
    if (this.hasLegendTarget) this.legendTarget.classList.remove("hidden") // analysis: show the non-loggable hint
    // Open ON a concrete selection only when there is one to honour: the user's saved choice, or - in analysis -
    // the featured EFW default (ready-to-run). A fresh map opens NEUTRAL ("Wszyscy wydawcy" + placeholder): we never
    // seed a specific (looks-random) publisher; the map still shows its own default indicator. The Wskaznik then
    // appears with a fade once the user actually picks a publisher.
    const saved = this.savedEntry()
    const seed = saved || (this.modeValue === "analysis" ? (this.byCode(this.initialValue) || this.firstSelectable()) : null)
    if (seed) this.openOn(seed)
    else this.openNeutral()
    this._ready = true // gate: animate only user-driven changes, not this initial render
  }

  openOn(entry) {
    this.scopeTarget.value = entry.scope
    this.buildRegionOptions(entry.scope)
    if (this.hasRegionTarget && entry.region) this.regionTarget.value = entry.region
    this.buildDziedzinaOptions()
    this.dziedzinaTarget.value = entry.dziedzina
    this.buildPublisherOptions()
    if (this.hasPublisherTarget && [...this.publisherTarget.options].some(o => o.value === entry.publisher)) {
      this.publisherTarget.value = entry.publisher
    }
    this.repopulate(entry.code)
  }

  openNeutral() {
    this.scopeTarget.value = "global"
    this.buildRegionOptions("global")
    this.buildDziedzinaOptions()
    this.dziedzinaTarget.value = "all"
    this.buildPublisherOptions() // "all" -> repopulate hits the "pick a publisher" placeholder, no dispatch
    this.repopulate()
  }

  // localStorage code remembered per mode (survives refresh/language switch; map is turbo-permanent).
  get storageKey() { return this.modeValue === "analysis" ? `picker_analysis_${this.roleValue}_indicator` : "picker_map_indicator" }
  savedEntry() {
    const e = this.byCode(localStorage.getItem(this.storageKey))
    return this.isSelectable(e) ? e : null
  }

  byCode(code) { return code ? this.catalog.find(e => e.code === code) : null }
  isSelectable(e) { return !!e && !(this.modeValue === "analysis" && e.computable === false) }
  firstSelectable() { return this.catalog.find(e => this.isSelectable(e)) }

  get reduced() { return window.matchMedia("(prefers-reduced-motion: reduce)").matches }

  // Smooth opacity fade (same feel as the explore<->analysis tab transitions). Opacity-only = composited.
  fadeIn(el) {
    if (this.reduced) { el.style.opacity = ""; return }
    el.style.transition = "none"; el.style.opacity = "0"
    requestAnimationFrame(() => { el.style.transition = "opacity var(--dur-fast) var(--ease-enter)"; el.style.opacity = "1" })
  }

  // Expand/collapse the conditional region field via grid-template-rows 1fr<->0fr: the fields below still
  // slide smoothly, but with no scrollHeight measurement (forced reflow) and no margin animation - the same JS-free
  // collapse pattern as the configurator. Finalized on transitionend (not a setTimeout cushion). The label is the
  // grid container (display:grid only during the animation), its single inner span (min-h-0 overflow-hidden) the track.
  expandField(el) {
    if (this.reduced) { el.classList.remove("hidden"); return }
    el.classList.remove("hidden")
    el.style.display = "grid"; el.style.transition = "none"
    el.style.gridTemplateRows = "0fr"; el.style.opacity = "0"
    void el.offsetHeight // commit the collapsed start state (one forced reflow, not per-frame)
    requestAnimationFrame(() => {
      el.style.transition = "grid-template-rows var(--dur-slower) var(--ease-enter), opacity var(--dur-base) var(--ease-enter)"
      el.style.gridTemplateRows = "1fr"; el.style.opacity = "1"
      this.onFieldEnd(el, () => { el.style.display = ""; el.style.gridTemplateRows = ""; el.style.opacity = ""; el.style.transition = "" })
    })
  }
  collapseField(el) {
    if (this.reduced) { el.classList.add("hidden"); return }
    el.style.display = "grid"; el.style.transition = "none"
    el.style.gridTemplateRows = "1fr"; el.style.opacity = "1"
    void el.offsetHeight
    requestAnimationFrame(() => {
      el.style.transition = "grid-template-rows var(--dur-slower) var(--ease-exit), opacity var(--dur-base) var(--ease-exit)"
      el.style.gridTemplateRows = "0fr"; el.style.opacity = "0"
      this.onFieldEnd(el, () => { el.classList.add("hidden"); el.style.display = ""; el.style.gridTemplateRows = ""; el.style.opacity = ""; el.style.transition = "" })
    })
  }
  // Run `done` when the grid-rows transition finishes (with a timeout fallback if transitionend never fires).
  onFieldEnd(el, done) {
    clearTimeout(el._animT)
    const handler = (e) => {
      if (e.target !== el || e.propertyName !== "grid-template-rows") return
      el.removeEventListener("transitionend", handler); clearTimeout(el._animT); done()
    }
    el.addEventListener("transitionend", handler)
    el._animT = setTimeout(() => { el.removeEventListener("transitionend", handler); done() }, durMs("--dur-slower", 420) + 100) // fallback > the grid-rows transition
  }

  // --- field events -------------------------------------------------------
  // Each facet rebuilds every facet BELOW it, so the cascade can never offer a value with nothing behind it.
  scopeChanged() {
    this.buildRegionOptions(this.scopeTarget.value)
    this.buildDziedzinaOptions()
    this.buildPublisherOptions()
    this.repopulate()
  }
  regionChanged()    { this.buildDziedzinaOptions(); this.buildPublisherOptions(); this.repopulate() }
  dziedzinaChanged() { this.buildPublisherOptions(); this.repopulate() }
  publisherChanged() { this.repopulate() }
  indicatorChanged() { this.applySelection(this.indicatorTarget.value) }

  // This picker's stable id - distinguishes the two analysis pickers (both mode=analysis) so the search overlay
  // can target one without touching the other. map | analysis-predictor | analysis-response.
  get pickerId() { return this.modeValue === "analysis" ? `analysis-${this.roleValue}` : "map" }

  // This picker's magnifier (beside the Wskaznik field) opens the shared search overlay, scoped to THIS picker.
  openSearch() { window.dispatchEvent(new CustomEvent("search:open", { detail: { target: this.pickerId } })) }

  // Search overlay picked an indicator for THIS picker (matched by id, not mode): set the whole cascade to where
  // it lives and select it. Only the targeted picker reacts - the other analysis picker is left untouched.
  searchSelect(event) {
    if (event.detail.target !== this.pickerId) return
    const entry = this.byCode(event.detail.code)
    if (entry && this.isSelectable(entry)) this.openOn(entry)
  }

  // Availability pool for building the option lists: the catalog under a chosen subset of the upstream facets,
  // and (in analysis) restricted to LOGGABLE indicators - so a field never offers a branch whose only endpoint is
  // a disabled predictor. The Wskaznik list itself (repopulate) does NOT use this - it shows non-loggable disabled.
  avail({ scope = true, region = true, dziedzina = true } = {}) {
    const s = this.scopeTarget.value
    const r = this.hasRegionTarget ? this.regionTarget.value : "all"
    const dz = this.dziedzinaTarget.value
    const regionActive = s === "regional" || s === "national"
    return this.catalog.filter(e =>
      (this.modeValue !== "analysis" || e.computable) &&
      (!scope || e.scope === s) &&
      (!region || !regionActive || r === "all" || e.region === r) &&
      (!dziedzina || dz === "all" || e.dziedzina === dz))
  }

  // Fill a facet <select>: a leading "all" option + one per value - EXCEPT when there is exactly one value, where
  // the "all" placeholder is pointless, so we show that single value alone (selected). Keeps the prior selection if
  // still valid, else falls back to "all" (or the sole value).
  fillFacet(target, values, labelFn, allLabel, fade = true) {
    const prev = target.value
    if (values.length === 1) {
      target.innerHTML = `<option value="${this.esc(values[0])}">${this.esc(labelFn(values[0]))}</option>`
      target.value = values[0]
    } else {
      const all = `<option value="all">${this.esc(allLabel || "-")}</option>`
      target.innerHTML = all + values.map(v => `<option value="${this.esc(v)}">${this.esc(labelFn(v))}</option>`).join("")
      target.value = values.includes(prev) ? prev : "all"
    }
    if (fade && this._ready) this.fadeIn(target, this.FADE_MS)
  }

  // --- region (conditional field) -----------------------------------------
  // Appears for Regionalne/Krajowe, hidden for Globalne - with a fade in/out (gated to user actions via _ready).
  buildRegionOptions(scope) {
    if (!this.hasRegionTarget) return
    const el = this.regionFieldTarget
    const active = scope === "regional" || scope === "national"
    const wasHidden = el.classList.contains("hidden")
    if (active) {
      const regions = [...new Set(this.catalog
        .filter(e => e.scope === scope && e.region && (this.modeValue !== "analysis" || e.loggable))
        .map(e => e.region))].sort((a, b) => this.regionLabel(a).localeCompare(this.regionLabel(b)))
      this.fillFacet(this.regionTarget, regions, r => this.regionLabel(r), this.regionLabelsValue.all, false)
      if (wasHidden) { if (this._ready) this.expandField(el); else el.classList.remove("hidden") }
      else if (this._ready) this.fadeIn(this.regionTarget) // already visible, options changed
    } else if (this._ready && !wasHidden) {
      this.collapseField(el)
    } else {
      el.classList.add("hidden")
    }
  }

  // --- dziedzina (theme) field --------------------------------------------
  // Only the themes that actually have indicators under the current Pokrycie+Region (and, in analysis, a loggable
  // one). This is the fix for the reported contradiction: picking Krajowe+kraj used to still offer all 11 themes.
  buildDziedzinaOptions() {
    const present = new Set(this.avail({ dziedzina: false }).map(e => e.dziedzina))
    const keys = Object.keys(this.dziedzinaLabelsValue).filter(k => present.has(k))
    this.fillFacet(this.dziedzinaTarget, keys, k => this.dziedzinaLabelsValue[k], this.allDziedzinaValue)
  }

  // --- publisher (Wydawca) field ------------------------------------------
  // Selecting a publisher shortens the Wskaznik list to that publisher - the real fix for a long list. Options are
  // the publishers present under the current Pokrycie+Region+Dziedzina (loggable in analysis); default "all".
  buildPublisherOptions() {
    if (!this.hasPublisherTarget) return
    const pubs = [...new Set(this.avail().map(e => e.publisher))].sort((a, b) => a.localeCompare(b))
    this.fillFacet(this.publisherTarget, pubs, p => p, this.allPublishersValue)
  }

  // --- the indicator list -------------------------------------------------
  repopulate(preferCode) {
    const want = preferCode || this.indicatorTarget.value
    // School-1: with more than one publisher available the Wydawca field reads "Wszyscy" - do NOT impose an
    // indicator from that ambiguous set. Prompt for a publisher and hold the previous selection (map/description).
    if (this.hasPublisherTarget && this.publisherTarget.value === "all") {
      this.indicatorTarget.innerHTML = `<option value="" disabled selected>${this.esc(this.pickPublisherValue)}</option>`
      if (this._ready) this.fadeIn(this.indicatorTarget, this.FADE_MS)
      return
    }
    const list = this.filtered()
    // Flat list, sorted by name. No optgroup headers: Wydawca and Kolekcja are their own field / description now,
    // so a per-Kolekcja group title in the dropdown is a leftover from older versions.
    const html = list.slice().sort((a, b) => a.name.localeCompare(b.name)).map(e => this.optionHTML(e)).join("")
    this.indicatorTarget.innerHTML = html || `<option value="" disabled>-</option>`
    // Keep the prior selection if still present + selectable, else fall to the first enabled option.
    const opts = [...this.indicatorTarget.querySelectorAll("option:not([disabled])")]
    const keep = opts.find(o => o.value === want)
    const pick = keep || opts[0]
    if (pick) { this.indicatorTarget.value = pick.value; this.applySelection(pick.value) }
    else { this.clearMeta() }
    if (this._ready) this.fadeIn(this.indicatorTarget, this.FADE_MS)
  }

  // The Wskaznik list: every indicator under all four facets (non-loggable INCLUDED - shown disabled in analysis).
  filtered() {
    const scope = this.scopeTarget.value
    const region = this.hasRegionTarget ? this.regionTarget.value : "all"
    const dz = this.dziedzinaTarget.value
    const publisher = this.hasPublisherTarget ? this.publisherTarget.value : "all"
    const regionActive = scope === "regional" || scope === "national"
    return this.catalog.filter(e =>
      e.scope === scope &&
      (!regionActive || region === "all" || e.region === region) &&
      (dz === "all" || e.dziedzina === dz) &&
      (publisher === "all" || e.publisher === publisher))
  }

  optionHTML(e) {
    const disabled = this.modeValue === "analysis" && e.loggable === false
    const mark = disabled ? " ⊘" : ""
    return `<option value="${this.esc(e.code)}"${disabled ? " disabled" : ""}>${this.esc(e.name)}${mark}</option>`
  }

  // --- selection side-effects ---------------------------------------------
  applySelection(code) {
    const e = this.byCode(code)
    if (!e) return
    if (this.hasMetaCollectionTarget) this.metaCollectionTarget.textContent = this.collectionDisplay(e.publisher, e.collection, e.publisher_short)
    if (this.hasMetaLicenseTarget) this.setLink(this.metaLicenseTarget, e.license, e.license_url)
    if (this.hasMetaLinkTarget) this.setLink(this.metaLinkTarget, this.host(e.link), e.link)
    this._scopeLabel = this.coverageLabel(e)
    this.updateCoverage()
    if (this._ready && this.hasDescriptionTarget) this.fadeIn(this.descriptionTarget, this.FADE_MS)
    localStorage.setItem(this.storageKey, code)
    if (this.modeValue === "map") {
      window.dispatchEvent(new CustomEvent("indicator:selected", { detail: { code: e.code, name: e.name } }))
    } else {
      // analysis: tell pvar the predictor/response changed (manual / cascade / search) so it re-validates coverage.
      window.dispatchEvent(new CustomEvent(`${this.roleValue}:selected`, { detail: { code: e.code, name: e.name } }))
    }
  }

  coverageLabel(e) {
    const scope = this.scopeLabelsValue[e.scope] || e.scope
    return (e.region && this.regionLabelsValue[e.region]) ? `${scope} · ${this.regionLabelsValue[e.region]}` : scope
  }

  // Map only: live country count + period from the choropleth.
  onLoaded(event) {
    const { yearRange, count } = event.detail || {}
    this._count = (count != null && count > 0) ? count : null
    this.updateCoverage()
    if (this.hasMetaPeriodTarget && yearRange && yearRange[0] != null) {
      this.metaPeriodTarget.textContent = `${yearRange[0]}-${yearRange[1]}`
    }
  }

  updateCoverage() {
    if (!this.hasMetaCoverageTarget) return
    const parts = []
    if (this._count != null) parts.push(`${this._count} ${this.regionLabelsValue.countries || ""}`.trim())
    if (this._scopeLabel) parts.push(this._scopeLabel)
    this.metaCoverageTarget.textContent = parts.length ? parts.join(" · ") : "-"
  }

  clearMeta() {
    if (this.hasMetaCollectionTarget) this.metaCollectionTarget.textContent = "-"
    if (this.hasMetaLicenseTarget) this.setLink(this.metaLicenseTarget, "-", null)
    if (this.hasMetaLinkTarget) this.setLink(this.metaLinkTarget, "-", null)
    this._scopeLabel = null
    this.updateCoverage()
  }

  // Source/license links in the description: set text + href, or drop the href so it renders as plain text.
  host(url) { if (!url) return null; try { return new URL(url).host } catch (_) { return url } }
  setLink(el, text, href) {
    el.textContent = text || "-"
    if (href) el.setAttribute("href", href); else el.removeAttribute("href")
  }

  // Collection title for the description. Prepend the publisher for context when it fits one line (<=34 chars):
  // prefer the full publisher (e.g. "ASEAN Secretariat - ASEANstats"); if that is too long but the publisher has an
  // acronym, use it ("FAO - FAOSTAT", "INEGI - National statistics"); else show the collection alone. The user has
  // already chosen the publisher in its own field, so the prefix is pure readability. The full publisher's trailing
  // parenthetical is dropped first so it never repeats the collection or blows the budget.
  COLLECTION_DISPLAY_MAX = 34
  collectionAcronym(s) { const m = (s || "").match(/\(([A-Z][A-Z0-9.\-]{1,9})\)/); return m ? m[1] : null }
  collectionDisplay(publisher, collection, short) {
    const coll = collection || "-"
    // usable: fits one line AND isn't just a repeat of the collection (e.g. skip "SEDLAC - SEDLAC").
    const fits = (p) => !!p && p !== coll && `${p} - ${coll}`.length <= this.COLLECTION_DISPLAY_MAX
    const full = (publisher || "").replace(/\s*\([^()]*\)\s*$/, "").trim()
    if (fits(full)) return `${full} - ${coll}`           // full publisher (e.g. "ASEAN Secretariat - ASEANstats")
    const acr = this.collectionAcronym(publisher)
    if (fits(acr)) return `${acr} - ${coll}`             // acronym from a parenthetical ("FAO - FAOSTAT")
    if (fits(short)) return `${short} - ${coll}`         // curated short ("GCC - National statistics", "OWID - Energy")
    return coll
  }

  regionLabel(key) { return this.regionLabelsValue[key] || key }
  esc(s) { return String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])) }
}
