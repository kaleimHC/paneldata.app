import { Controller } from "@hotwired/stimulus"

// Drives a PVAR run: validate -> POST /analyses -> poll status every 2s. The RESULT itself is
// rendered SERVER-SIDE (AnalysisResultComponent); on completion we navigate to /?run=<id> - a real Turbo visit
// (like Methodology) so the page cross-fades in via the view-transition instead of an in-place JS swap that
// jumped. This controller therefore only owns: validation, submit, polling, and the back-to-config swap.
export default class extends Controller {
  static targets = ["predictor", "response", "startYear", "endYear", "bootstrap", "runButton",
                    "status", "validation", "resultsBlock", "configPlaceholder"]
  static values = { validationLabels: Object, labels: Object, nExclude: { type: Number, default: 10 } }

  KEY = "pvar_active_run"

  connect() {
    this.onPair = () => this.validate()
    window.addEventListener("predictor:selected", this.onPair) // explanatory picker (manual/cascade/search)
    window.addEventListener("response:selected", this.onPair)  // response picker
    this.onConfig = () => this.enterConfigMode()
    window.addEventListener("analysis:config", this.onConfig)  // "Uruchom analize" tab re-click -> back to config-mode
    this._cov = {}; this._running = false; this._valid = false
    this.validate() // instant client-side pre-run check (coverage maps -> balanced count)
    // Reattach to an IN-PROGRESS run after a refresh (its id is in localStorage); a completed one just navigates.
    // Skip when the page already loaded in result-mode (server rendered a run) - nothing to reattach.
    const id = localStorage.getItem(this.KEY)
    if (id && this.element.dataset.analysisMode !== "result") this.loadRun(id)
  }

  disconnect() {
    this.stop()
    window.removeEventListener("predictor:selected", this.onPair)
    window.removeEventListener("response:selected", this.onPair)
    window.removeEventListener("analysis:config", this.onConfig)
  }

  // Navigate to the server-rendered result (Turbo visit -> view-transition cross-fade; the turbo-permanent map stays).
  navigate(id) {
    const url = `${location.pathname}?run=${id}`
    if (window.Turbo) window.Turbo.visit(url)
    else window.location.assign(url)
  }

  // Back to config-mode (analysis tab re-click): re-expand the configurator (CSS grid-rows), restore the static
  // results placeholder over the server-rendered run, and drop ?run from the URL without a reload.
  enterConfigMode() {
    this.element.dataset.analysisMode = "config"
    if (this.hasResultsBlockTarget && this.hasConfigPlaceholderTarget) {
      this.resultsBlockTarget.innerHTML = this.configPlaceholderTarget.innerHTML
    }
    if (location.search.includes("run=")) history.replaceState({}, "", location.pathname)
    localStorage.removeItem(this.KEY)
  }
  stop() { if (this.timer) { clearInterval(this.timer); this.timer = null } }

  // ---- instant client-side validation ----
  // Coverage maps (country -> run-length year ranges) are fetched lazily per indicator and cached; the balanced
  // country count for the chosen period is then computed in pure JS - identical to PanelBuilder.n_countries.
  periodChanged() { this.validate() }

  async coverage(code) {
    if (!code) return null
    if (this._cov[code]) return this._cov[code]
    try {
      const r = await fetch(`/indicators/coverage?code=${encodeURIComponent(code)}`, { headers: { Accept: "application/json" } })
      if (!r.ok) return null
      return (this._cov[code] = await r.json())
    } catch (_) { return null }
  }

  async validate() {
    if (!this.hasPredictorTarget) return // result-mode: no configurator inputs present
    const pc = this.predictorTarget.value
    const rc = this.hasResponseTarget ? this.responseTarget.value : null
    if (!pc || !rc) { this.vstatus("pick_indicator", "muted"); this.setValid(false); return }
    const [A, B] = await Promise.all([this.coverage(rc), this.coverage(pc)])
    if (this.predictorTarget.value !== pc) return            // predictor changed mid-fetch; a later validate() wins
    if (!A || !B) { this.vstatus("checking", "muted"); this.setValid(false); return }

    const [cmin, cmax] = this.commonRange(A, B)
    if (cmin == null || cmin > cmax) { this.vstatus("no_years", "bad"); this.setValid(false); return }
    this.clampPeriod(cmin, cmax)

    const s = parseInt(this.startYearTarget.value, 10), e = parseInt(this.endYearTarget.value, 10)
    const T = e - s + 1
    if (T < 5) { this.vstatus("too_short", "bad", { from: cmin, to: cmax }); this.setValid(false); return }
    // Min countries depends on bootstrap: pvar.R jackknifes out n_exclude countries per iteration and STOPS if
    // n_exclude >= n_countries, so a bootstrapped run needs > n_exclude. n_bootstrap=0 only needs the AB-GMM floor (5).
    const nb = parseInt(this.bootstrapTarget.value, 10) || 0
    const minN = nb > 0 ? this.nExcludeValue + 1 : 5
    const n = this.balancedCount(A, B, s, e)
    if (n < minN) { this.vstatus("few_countries", "bad", { n, min: minN }); this.setValid(false); return }
    if (T <= 7) { this.vstatus("short_panel", "warn", { n, t: T }); this.setValid(true); return }
    this.vstatus("ok", "good", { n, from: s, to: e }); this.setValid(true)
  }

  // overall [min,max] year where BOTH indicators have data somewhere (loose slider bound; exact count below).
  commonRange(A, B) {
    const span = (m) => { let lo = Infinity, hi = -Infinity; for (const k in m) for (const r of m[k]) { if (r[0] < lo) lo = r[0]; if (r[1] > hi) hi = r[1] } return [lo, hi] }
    const [a0, a1] = span(A), [b0, b1] = span(B)
    if (!isFinite(a0) || !isFinite(b0)) return [null, null]
    return [Math.max(a0, b0), Math.min(a1, b1)]
  }

  // exact strict-balance count: countries present in BOTH series for EVERY year in [s,e] (== PanelBuilder).
  balancedCount(A, B, s, e) {
    const inAll = (ranges) => { for (let y = s; y <= e; y++) if (!ranges.some(r => y >= r[0] && y <= r[1])) return false; return true }
    let n = 0
    for (const iso in A) if (B[iso] && inAll(A[iso]) && inAll(B[iso])) n++
    return n
  }

  clampPeriod(lo, hi) {
    ;[this.startYearTarget, this.endYearTarget].forEach(i => { i.min = lo; i.max = hi })
    let s = parseInt(this.startYearTarget.value, 10), e = parseInt(this.endYearTarget.value, 10)
    if (isNaN(s) || s < lo) s = lo; if (s > hi) s = hi
    if (isNaN(e) || e > hi) e = hi; if (e < lo) e = lo
    if (e < s) e = s
    this.startYearTarget.value = s; this.endYearTarget.value = e
  }

  setValid(v) { this._valid = v; this.refreshRun() }
  refreshRun() { if (this.hasRunButtonTarget) this.runButtonTarget.disabled = !(this._valid && !this._running) }

  vstatus(key, kind, vars = {}) {
    if (!this.hasValidationTarget) return
    let s = (this.validationLabelsValue && this.validationLabelsValue[key]) || key
    for (const k in vars) s = s.replaceAll(`{${k}}`, vars[k]) // {n}/{from}/{to}; not %{} so Rails t() won't interpolate
    const cls = { good: "text-ok", warn: "text-warn", bad: "text-bad", muted: "text-ink-muted" }[kind] || "text-ink-muted"
    this.validationTarget.textContent = s
    this.validationTarget.className = `text-xs ${cls}`
  }

  // i18n for controller-rendered run-status strings (data-pvar-labels-value); {k} interpolation (not %{}).
  lbl(key, vars = {}) {
    let s = (this.labelsValue && this.labelsValue[key]) || key
    for (const k in vars) s = s.replaceAll(`{${k}}`, vars[k])
    return s
  }

  // Reattach the view to an in-progress run (refresh): poll until it finishes, then navigate to the result.
  loadRun(id) {
    this.stop()
    fetch(`/analyses/${id}`, { headers: { Accept: "application/json" } })
      .then(r => r.ok ? r.json() : null)
      .then(d => {
        if (!d) return localStorage.removeItem(this.KEY)
        if (d.status === "completed") { localStorage.removeItem(this.KEY); this.navigate(id) }
        else if (d.status === "failed") { localStorage.removeItem(this.KEY); this.fail(d.error || "computation failed") }
        else { localStorage.setItem(this.KEY, id); this.busy(this.lbl("running", { progress: d.progress || 0, total: d.n_bootstrap || 0 })); this.poll(id) }
      })
      .catch(() => {})
  }

  run() {
    if (!this._valid) return // gated: invalid config can't be submitted (button is also disabled)
    this.stop()
    const body = JSON.stringify({
      predictor_code: this.predictorTarget.value,
      response_code: this.hasResponseTarget ? this.responseTarget.value : undefined,
      start_year: this.startYearTarget.value,
      end_year: this.endYearTarget.value,
      n_bootstrap: this.bootstrapTarget.value
    })
    this.busy(this.lbl("queued"))
    fetch("/analyses", { method: "POST", body,
      headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrf, "Accept": "application/json" } })
      .then(r => r.json())
      .then(d => {
        if (d.error) return this.fail(d.error)
        localStorage.setItem(this.KEY, d.id)
        window.dispatchEvent(new CustomEvent("runs:changed")) // show the new (pending) run in the history list
        this.poll(d.id)
      })
      .catch(e => this.fail(e.message))
  }

  poll(id) {
    this.timer = setInterval(() => {
      fetch(`/analyses/${id}`, { headers: { "Accept": "application/json" } })
        .then(r => r.json())
        .then(d => {
          if (d.status === "running") this.busy(this.lbl("running", { progress: d.progress || 0, total: d.n_bootstrap || 0 }))
          else if (d.status === "pending") this.busy(this.lbl("queued"))
          else if (d.status === "completed") { this.stop(); localStorage.removeItem(this.KEY); window.dispatchEvent(new CustomEvent("runs:changed")); this.navigate(id) }
          else if (d.status === "failed") { this.stop(); localStorage.removeItem(this.KEY); this.fail(d.error || "computation failed"); window.dispatchEvent(new CustomEvent("runs:changed")) }
        })
        .catch(e => { this.stop(); this.fail(e.message) })
    }, 2000)
  }

  // ---- run status text (lives under the Run button, in the configurator) ----
  get csrf() { return document.querySelector('meta[name="csrf-token"]')?.content || "" }
  busy(msg) {
    this._running = true
    if (this.hasRunButtonTarget) this.runButtonTarget.disabled = true
    if (this.hasStatusTarget) { this.statusTarget.textContent = msg; this.statusTarget.className = "text-xs text-warn" }
  }
  fail(msg) {
    this._running = false
    this.refreshRun()
    if (this.hasStatusTarget) { this.statusTarget.textContent = this.lbl("failed", { msg }); this.statusTarget.className = "text-xs text-bad" }
  }
}
