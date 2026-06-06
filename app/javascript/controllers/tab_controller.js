import { Controller } from "@hotwired/stimulus"
import { durMs } from "controllers/motion"

// In-page tab views (a4): top-bar tabs switch the MAIN column; left rail (workspace) persists. NO URL change,
// NO routes. Dispatches tab:shown so the map can resize (MapLibre renders empty if its container was display:none).
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    if (!this.element.dataset.view) this.element.dataset.view = "explore"
    // A run opened from history loads at /?run=<id>: the server already rendered analysis view + result-mode, so
    // DON'T restore a stale saved tab over it (would bounce back to explore). Otherwise restore the last tab.
    if (new URLSearchParams(location.search).has("run")) {
      localStorage.setItem("active_tab", "analysis")
    } else {
      const saved = localStorage.getItem("active_tab")
      if ((saved === "explore" || saved === "analysis") && saved !== this.element.dataset.view) this.restore(saved)
    }
    // Back-to-config (analysis tab re-click -> pvar drops ?run) un-dims the analysis tab. (Selecting a run no longer
    // fires a client event - it's a Turbo visit, so the server renders the dimmed state directly.)
    this.onAnalysisConfig = () => this.analysisUnderline(true)
    window.addEventListener("analysis:config", this.onAnalysisConfig)
  }

  restore(name) {
    this.element.dataset.view = name
    this.panelTargets.forEach(p => { p.hidden = p.dataset.tabName !== name })
    this.tabTargets.forEach(t => this.paintTab(t, t.dataset.tabName === name))
    window.dispatchEvent(new CustomEvent("tab:shown", { detail: { name } }))
  }

  // Single source of truth for a tab's look so hover behaviour can't drift between the active/inactive tabs:
  // active = gold (text-tab), NO hover change; inactive = muted with hover:text-ink. The hover class must be
  // toggled here too - if left static in the ERB it sticks to the render-time tab and the hover goes lopsided.
  paintTab(t, active) {
    t.setAttribute("aria-selected", active ? "true" : "false")
    t.classList.toggle("border-tab", active)
    t.classList.toggle("font-medium", active)
    t.classList.toggle("text-tab", active)
    t.classList.toggle("border-transparent", !active)
    t.classList.toggle("text-ink-muted", !active)
    t.classList.toggle("hover:text-ink", !active)
  }

  select(event) {
    const name = event.currentTarget.dataset.tabName
    // Re-clicking the already-open ANALYSIS tab = back to config-mode (re-expand the configurator, deselect the run).
    // Re-clicking explore stays a pure no-op.
    if (name === (this.element.dataset.view || "explore")) {
      if (name === "analysis") window.dispatchEvent(new CustomEvent("analysis:config"))
      return
    }
    this.show(name)
  }

  // Unique selection: config-mode -> the "Uruchom analize" tab is active (underline + theme label); a run
  // selected -> the tab is FULLY DESELECTED (dimmed like the inactive Explore tab), so the only active marker is the
  // history run's border. Reuses paintTab (single source of truth for tab look) - no half-active state.
  analysisUnderline(on) {
    const t = this.tabTargets.find(x => x.dataset.tabName === "analysis")
    if (t) this.paintTab(t, on)
  }

  show(name) {
    localStorage.setItem("active_tab", name)   // remembered across refreshes (restored in connect)
    const root = this.element
    const oldView = root.dataset.view || "explore"
    const rail = root.querySelector("[data-rail]")
    const stage = root.querySelector("[data-stage]")
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    const mobile = window.matchMedia("(max-width: 767.98px)").matches
    const animate = !!stage && !reduced        // content cross-fade on BOTH desktop and mobile
    const slide = animate && mobile && !!rail  // rail FLIP-slide only on mobile (desktop rail is static)

    // Highlight the clicked tab immediately (before the content transition).
    this.tabTargets.forEach(t => this.paintTab(t, t.dataset.tabName === name))
    // Entering analysis from explore = fresh config-mode: clear any stale result selection/underline.
    if (name === "analysis") window.dispatchEvent(new CustomEvent("analysis:config"))

    // The opacity-faded set for a view = that view's PANEL + its rail section (explore → data-selection;
    // analysis → run history). The theme switcher (mobile-explore-only) joins the explore set only on mobile.
    // The turbo-permanent map (#coverage-map, ) is the fixed anchor: it must NEVER opacity-fade (a permanent
    // hero that still fades from zero is a contradiction), so we drop anything that is or contains it - the map
    // snaps in/out via panel.hidden while only the surrounding panel content cross-fades.
    const mapNode = root.querySelector("#coverage-map")
    const scoped = (view) => {
      const panel = root.querySelector(`[data-tab-target="panel"][data-tab-name="${view}"]`)
      const sels = [`[data-${view}-only]`]
      if (view === "explore" && mobile) sels.push("[data-mobile-explore-only]")
      return [panel, ...root.querySelectorAll(sels.join(","))]
        .filter(el => el && el !== mapNode && !(mapNode && el.contains(mapNode)))
    }

    const swap = () => {
      // FLIP "First": rail position before the layout change (mobile only).
      let firstTop = null
      if (slide) { rail.style.transition = "none"; rail.style.transform = "none"; firstTop = rail.getBoundingClientRect().top }

      // State change - single source of truth ([data-view]) drives the Explore↔Analysis layout via CSS.
      root.dataset.view = name
      this.panelTargets.forEach(p => { p.hidden = p.dataset.tabName !== name })

      // Incoming content starts invisible; fades in after the rail lands (mobile) or right away (desktop).
      const showing = scoped(name)
      showing.forEach(el => { el.style.transition = "none"; el.style.opacity = "0" })
      let faded = false
      const fadeIn = () => {
        if (faded) return
        faded = true
        if (slide) { rail.style.transition = ""; rail.style.transform = "" }
        clearTimeout(this._fadeTimer)
        requestAnimationFrame(() => showing.forEach(el => { el.style.transition = "opacity var(--dur-base) var(--ease-enter)"; el.style.opacity = "1" }))
      }

      if (slide) {
        // FLIP "Invert → Play": jump the rail to its old spot, COMMIT with a forced reflow (a single rAF is
        // unreliable on mobile Chrome → jump), then glide it to the new one.
        const delta = firstTop - rail.getBoundingClientRect().top
        if (Math.abs(delta) > 1) {
          rail.style.transition = "none"
          rail.style.transform = `translateY(${delta}px)`
          void rail.offsetHeight
          rail.style.transition = "transform var(--dur-slower) var(--ease-enter)"
          rail.style.transform = "none"
          const done = (e) => { if (e.propertyName !== "transform") return; rail.removeEventListener("transitionend", done); fadeIn() }
          rail.addEventListener("transitionend", done)
          this._fadeTimer = setTimeout(fadeIn, durMs("--dur-slower", 420) + 150) // fallback if transitionend never fires
        } else { fadeIn() }
      } else {
        fadeIn() // desktop (no rail slide): fade the new content in right after the swap
      }
      window.dispatchEvent(new CustomEvent("tab:shown", { detail: { name } }))
    }

    clearTimeout(this._swapTimer)
    clearTimeout(this._fadeTimer)
    if (!animate) {
      root.dataset.view = name
      this.panelTargets.forEach(p => { p.hidden = p.dataset.tabName !== name })
      ;[stage, rail, ...root.querySelectorAll("[data-tab-target='panel'],[data-explore-only],[data-analysis-only],[data-mobile-explore-only]")]
        .forEach(el => { if (el) { el.style.transition = ""; el.style.transform = ""; el.style.opacity = "" } })
      window.dispatchEvent(new CustomEvent("tab:shown", { detail: { name } }))
      return
    }
    // Fade the OUTGOING content out (the old view's panel + rail section, never the map), then swap → fade in.
    scoped(oldView).forEach(el => { el.style.transition = "opacity var(--dur-base) var(--ease-exit)"; el.style.opacity = "0" })
    this._swapTimer = setTimeout(swap, durMs("--dur-base", 240))
  }

  disconnect() {
    clearTimeout(this._swapTimer); clearTimeout(this._fadeTimer)
    window.removeEventListener("analysis:config", this.onAnalysisConfig)
  }
}
