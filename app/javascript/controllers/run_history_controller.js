import { Controller } from "@hotwired/stimulus"

// Run history (sidebar): a scannable list of recent PVAR runs - each card shows the key metric (gamma_12)
// so you read "what came out", not just "that it ran". Click a card to reload that run into the main panel.
// Backend is trivial (the runs already persist); this is pure view. Stays in sync via the "runs:changed"
// window event (dispatched by the pvar controller) plus a light poll while any run is still computing.
export default class extends Controller {
  static targets = ["list", "empty"]
  static values = { labels: Object } // i18n: today/yesterday/older/failed/queued/delete
  lbl(k) { return (this.labelsValue && this.labelsValue[k]) || k }

  connect() {
    this._activeId = this.activeId(); this._seen = new Set(); this._seenInit = false
    this.onChanged = () => this.load()
    window.addEventListener("runs:changed", this.onChanged)
    this.onConfig = () => { this._activeId = null; this.markActive() } // client back-to-config dropped ?run -> deselect
    window.addEventListener("analysis:config", this.onConfig)
    this.load()
  }
  disconnect() {
    window.removeEventListener("runs:changed", this.onChanged)
    window.removeEventListener("analysis:config", this.onConfig)
    this.stop()
  }
  // The selected run is the one in the URL (?run=<id>) - the history navigates there as a Turbo visit.
  activeId() { return new URLSearchParams(location.search).get("run") }
  stop() { if (this.timer) { clearInterval(this.timer); this.timer = null } }

  load() {
    fetch("/analyses", { headers: { Accept: "application/json" } })
      .then(r => r.ok ? r.json() : [])
      .then(runs => { this.render(runs); this.schedule(runs) })
      .catch(() => {})
  }

  // Poll only while something is still computing; idle lists don't poll.
  schedule(runs) {
    const active = runs.some(r => r.status === "running" || r.status === "pending")
    this.stop()
    if (active) this.timer = setInterval(() => this.load(), 4000)
  }

  render(runs) {
    if (!runs.length) {
      this.listTarget.innerHTML = ""
      if (this.hasEmptyTarget) this.emptyTarget.classList.remove("hidden")
      return
    }
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")

    const prevSeen = this._seen
    this._seen = new Set(runs.map(r => String(r.id)))
    const isNew = (r) => this._seenInit && !prevSeen.has(String(r.id)) // animate only cards added after the first render

    const groups = { today: [], yesterday: [], older: [] }
    runs.forEach(r => groups[this.bucket(r.created_at)].push(r))

    this.listTarget.innerHTML = Object.entries(groups)
      .filter(([, rs]) => rs.length)
      .map(([key, rs]) =>
        `<div class="pt-1 text-[10px] font-medium uppercase tracking-wider text-ink-muted">${this.esc(this.lbl(key))}</div>
         ${rs.map(r => this.card(r, isNew(r))).join("")}`)
      .join("")
    this._seenInit = true
    this.markActive()

    // Completed cards are <a href="?run=id"> - Turbo handles the visit; we only intercept the delete button so a
    // click on the × neither follows the link nor bubbles.
    this.listTarget.querySelectorAll("[data-delete-id]").forEach(el =>
      el.addEventListener("click", (e) => { e.preventDefault(); e.stopPropagation(); this.remove(el.dataset.deleteId) }))
  }

  // Apply the "selected run" look (thicker theme-color border) to the active card; clears it from the rest.
  // Mutually-exclusive class sets so border-2/border never coexist.
  markActive() {
    if (!this.hasListTarget) return
    this.listTarget.querySelectorAll("[data-run-id]").forEach(el => {
      const on = el.dataset.runId === this._activeId
      el.classList.toggle("border-2", on); el.classList.toggle("border-tab", on)
      el.classList.toggle("border", !on); el.classList.toggle("border-edge", !on)
    })
  }

  remove(id) {
    fetch(`/analyses/${id}`, { method: "DELETE",
      headers: { "X-CSRF-Token": this.csrf, Accept: "application/json" } })
      .then(() => this.load())
      .catch(() => {})
  }
  get csrf() { return document.querySelector('meta[name="csrf-token"]')?.content || "" }

  // Card layout (one uniform "formatka"): predictor on the top row (status dot), response on its own
  // second row led by the arrow, then a single mono param line - period · boots · γ₁₂ = value - so
  // everything shares one font and the result sits inline (not a separate-font corner badge).
  card(r, isNew = false) {
    const metric = this.metric(r)
    const active = String(r.id) === this._activeId
    const cls = `relative block w-full rounded-lg ${active ? "border-2 border-tab" : "border border-edge"} bg-surface px-3 py-2 text-left transition-colors duration-[var(--dur-instant)] ease-[var(--ease-standard)] hover:bg-raised${isNew ? " run-enter" : ""}`
    const inner = `
      <button type="button" data-delete-id="${r.id}" aria-label="${this.esc(this.lbl('delete'))}" title="${this.esc(this.lbl('delete'))}"
        class="absolute right-1 top-1 flex h-4 w-4 items-center justify-center rounded border border-edge bg-surface text-[11px] leading-none text-ink-muted hover:border-bad hover:text-bad">×</button>
      <div class="flex items-center gap-2 pr-5">
        <span class="h-1.5 w-1.5 shrink-0 rounded-full ${this.dot(r.status)}"></span>
        <span class="truncate font-serif text-xs text-ink" title="${this.esc(r.predictor)}">${this.esc(r.predictor || "?")}</span>
      </div>
      <div class="truncate pl-3.5 font-serif text-xs text-ink-soft" title="${this.esc(r.response || "GDP")}"><span class="text-ink-muted">→</span> ${this.esc(r.response || "GDP")}</div>
      <div class="mt-0.5 truncate pl-3.5 font-mono text-[10px] text-ink-muted">${r.start_year}-${r.end_year} · ${r.n_bootstrap} boots · <span class="${metric.cls}">${metric.text}</span></div>`
    // Completed -> a real link (Turbo visit to the server-rendered result). In-progress/failed -> a plain card
    // (nothing to navigate to yet); the user's own running run is reattached via localStorage on refresh.
    return r.status === "completed"
      ? `<a href="${location.pathname}?run=${r.id}" data-run-id="${r.id}" class="${cls} cursor-pointer">${inner}</a>`
      : `<div data-run-id="${r.id}" class="${cls}">${inner}</div>`
  }

  metric(r) {
    if (r.status === "completed") {
      const g = r.gamma_12
      return { text: `γ₁₂ = ${this.fmt(g)}`, cls: g < 0 ? "text-bad" : "text-ink-soft" }
    }
    if (r.status === "running") return { text: `${r.progress || 0}/${r.n_bootstrap || 0}`, cls: "text-warn" }
    if (r.status === "failed") return { text: this.lbl("failed"), cls: "text-bad" }
    return { text: this.lbl("queued"), cls: "text-ink-muted" }
  }

  dot(s) {
    return s === "completed" ? "bg-ok"
      : s === "running" ? "bg-warn animate-pulse"
      : s === "failed" ? "bg-bad" : "bg-info"
  }

  bucket(iso) {
    const d = new Date(iso), now = new Date()
    const day = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime()
    const diff = (day(now) - day(d)) / 86400000
    return diff <= 0 ? "today" : diff <= 1 ? "yesterday" : "older"
  }

  fmt(v) { return (v === null || v === undefined) ? "-" : Number(v).toFixed(3) }
  esc(s) { const d = document.createElement("div"); d.textContent = s ?? ""; return d.innerHTML }
}
