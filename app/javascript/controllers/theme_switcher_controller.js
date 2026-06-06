import { Controller } from "@hotwired/stimulus"
import { durMs } from "controllers/motion"

// Layer 3 - theme switcher. Sets [data-theme] on <html>, persists to a 1y cookie,
// broadcasts theme:changed (so map/chart layers can re-tint in FAZA B).
export default class extends Controller {
  static targets = ["selector"]

  connect() {
    this.syncDropdownWithCurrentTheme()
    // A Turbo navigation/morph must never START with the universal .theme-transition armed: it would double-animate
    // with the view-transition root cross-fade and re-arm on morphed-in nodes (the class lives on <html>, which Turbo
    // persists across a morph). Strip it before every render - more robust than relying on the removal timer alone.
    this.onBeforeRender = () => document.documentElement.classList.remove("theme-transition")
    document.addEventListener("turbo:before-render", this.onBeforeRender)
  }

  change(event) {
    this.applyTheme(event.target.value)
  }

  applyTheme(themeName) {
    const root = document.documentElement
    // Arm the scoped color transition (application.css) BEFORE swapping vars, so the whole page cross-fades
    // in sync with the map; remove it after the transition so hover/focus stay instant (not globally transitioned).
    root.classList.add("theme-transition")
    root.setAttribute("data-theme", themeName)
    const expiration = new Date()
    expiration.setFullYear(expiration.getFullYear() + 1)
    document.cookie = `theme=${themeName}; expires=${expiration.toUTCString()}; path=/; SameSite=Lax`
    window.dispatchEvent(new CustomEvent("theme:changed", { detail: { theme: themeName } }))
    clearTimeout(this._themeTimer)
    this._themeTimer = setTimeout(() => root.classList.remove("theme-transition"), durMs("--dur-slow", 320) + 60)
  }

  disconnect() {
    clearTimeout(this._themeTimer)
    document.removeEventListener("turbo:before-render", this.onBeforeRender)
  }

  syncDropdownWithCurrentTheme() {
    if (this.hasSelectorTarget) {
      this.selectorTarget.value =
        document.documentElement.getAttribute("data-theme") || "light"
    }
  }
}
