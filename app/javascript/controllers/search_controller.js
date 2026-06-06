import { Controller } from "@hotwired/stimulus"

// INDICATOR SEARCH. An overlay that fuzzy-searches the indicator catalog (Fuse.js, lazy-imported) and, on
// click, drives the TARGETED picker via indicator:search-select -> picker.openOn(entry), so the cascade fields land
// on where the indicator lives. Opened by each picker's magnifier (search:open {target}); the header names the field.
//
//   MOUSE-ONLY: type to filter, click a row to pick, × / backdrop to close. No keyboard affordances (no ⌘K, no
//               arrow-nav) - deliberate product decision.
//   LOCALE-AWARE + diacritic-insensitive: the catalog name is display_name (~99.9% translated), and we index FOLDED
//               fields plus the human dziedzina/scope LABELS and publisher acronyms - so "PKB", "zdrowie", "dlugosc"
//               (no ogonki) and "WGI" all hit, not just exact English.
export default class extends Controller {
  static targets = ["overlay", "input", "results", "header"]
  static values = { scopeLabels: Object, dziedzinaLabels: Object, titles: Object, noResults: String }

  connect() { this._items = []; this._target = "map" }

  // catalog: the one shared <script data-indicator-catalog> in the page. No extra copy.
  readCatalog() {
    const el = document.querySelector("[data-indicator-catalog]")
    try { return JSON.parse(el.textContent) } catch (_) { return [] }
  }

  // Accent folding so a no-diacritic query matches accented names. NFD strips combining marks; ł/Ł don't decompose
  // under NFD, so map them explicitly. Lowercased first so Ł -> ł -> l.
  fold(s) {
    return String(s == null ? "" : s).toLowerCase().replace(/ł/g, "l")
      .normalize("NFD").replace(/[̀-ͯ]/g, "")
  }

  async ensureFuse() {
    if (this._fuse) return
    const { default: Fuse } = await import("fuse.js")
    // Index FOLDED, LOCALE-aware fields: display name, code, publisher (+ short acronym), collection, and the human
    // dziedzina/scope LABELS (not the internal keys). Originals stay on the item via spread (used for rendering).
    const docs = this.readCatalog().map(e => ({
      ...e,
      _name: this.fold(e.name),
      _code: this.fold(e.code),
      _publisher: this.fold([e.publisher, e.publisher_short].filter(Boolean).join(" ")),
      _collection: this.fold(e.collection),
      _dziedzina: this.fold(this.dziedzinaLabelsValue[e.dziedzina] || e.dziedzina),
      _scope: this.fold(this.scopeLabelsValue[e.scope] || e.scope)
    }))
    this._fuse = new Fuse(docs, {
      threshold: 0.4, ignoreLocation: true, minMatchCharLength: 2,
      keys: [
        { name: "_name", weight: 0.6 }, { name: "_code", weight: 0.15 },
        { name: "_publisher", weight: 0.1 }, { name: "_collection", weight: 0.08 },
        { name: "_dziedzina", weight: 0.05 }, { name: "_scope", weight: 0.02 }
      ]
    })
  }

  // A picker's magnifier asked to open the overlay for its field (detail.target = map | analysis-predictor | -response).
  openFor(e) { this.openTarget(e.detail && e.detail.target) }

  async openTarget(target) {
    this._target = target || "map"
    await this.ensureFuse()
    if (this.hasHeaderTarget) this.headerTarget.textContent = this.titlesValue[this._target] || ""
    this._opener = document.activeElement   // restore focus here on close (a11y hygiene; not a keyboard feature)
    this.overlayTarget.hidden = false
    this.inputTarget.value = ""
    this.resultsTarget.innerHTML = ""
    this._items = []
    this.inputTarget.focus()
  }

  close() { this.overlayTarget.hidden = true; if (this._opener && this._opener.focus) this._opener.focus() }
  backdrop(e) { if (e.target === this.overlayTarget) this.close() }

  // Analysis fields gate on loggability (both predictor and response go through log); the map does not.
  get analysisContext() { return this._target !== "map" }

  query() {
    const raw = this.inputTarget.value.trim()
    if (raw.length < 2) { this._items = []; this.resultsTarget.innerHTML = ""; return }
    let items = this._fuse.search(this.fold(raw)).map(r => r.item)
    // Analysis: drop non-computable (non-loggable OR NoDerivatives map-only) BEFORE the cap, so a screenful of
    // map-only hits can't starve the computable ones.
    if (this.analysisContext) items = items.filter(e => e.computable !== false)
    this._items = items.slice(0, 30)
    this.renderResults()
  }

  renderResults() {
    if (!this._items.length) {
      this.resultsTarget.innerHTML = `<li class="px-4 py-3 text-ink-muted">${this.esc(this.noResultsValue)}</li>`
      return
    }
    this.resultsTarget.innerHTML = this._items.map((e, i) => {
      const chips = [e.publisher, this.dziedzinaLabelsValue[e.dziedzina], this.scopeLabelsValue[e.scope]]
        .filter(Boolean)
        .map(c => `<span class="facet-chip">${this.esc(c)}</span>`)
        .join("")
      return `<li role="option" data-i="${i}" data-code="${this.esc(e.code)}"
                  class="cursor-pointer px-4 py-2 hover:bg-raised">
                <div class="text-ink">${this.esc(e.name)}</div>
                <div class="mt-1 flex flex-wrap gap-1">${chips}</div>
              </li>`
    }).join("")
  }

  clickResult(e) {
    const li = e.target.closest("li[data-i]")
    if (li) this.choose(Number(li.dataset.i))
  }

  choose(i) {
    const e = this._items[i]
    if (!e) return
    // Target the specific picker by id (NOT the mode): in analysis both pickers are mode=analysis, so the
    // predictor/response magnifiers each set only their own field.
    window.dispatchEvent(new CustomEvent("indicator:search-select", { detail: { code: e.code, target: this._target } }))
    this.close()
  }

  esc(s) { return String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])) }
}
