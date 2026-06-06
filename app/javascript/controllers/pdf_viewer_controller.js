import { Controller } from "@hotwired/stimulus"

// Methodology reading view: switch between the Goes teaser (default - two fair-use first-page images) and
// the full Replication PDF.js viewer. No live Goes PDF is ever served, only the pre-rendered images.
export default class extends Controller {
  static targets = ["tab", "replication", "goes"]

  KEY = "methodology_doc"

  // Restore the doc the user was on (persisted in localStorage), so a language switch keeps Replication
  // instead of snapping back to Goes - same persistence pattern as the Explore/Analysis tab on the home page.
  // Goes is the default only on a first visit. Instant (no animation) on initial load.
  connect() {
    const saved = localStorage.getItem(this.KEY)
    this.set(saved === "replication" ? "replication" : "goes")
  }

  // User tab switch: wrap the swap in the same View Transitions API Turbo uses for page transitions, so
  // Goes <-> Replication cross-fades exactly like a page change. Instant fallback where unsupported.
  switch(event) {
    const doc = event.currentTarget.dataset.doc
    if (document.startViewTransition) document.startViewTransition(() => this.set(doc))
    else this.set(doc)
  }

  set(doc) {
    localStorage.setItem(this.KEY, doc)
    this.tabTargets.forEach(t => t.setAttribute("aria-selected", t.dataset.doc === doc ? "true" : "false"))
    const isRepl = doc === "replication"
    this.replicationTarget.hidden = !isRepl
    this.goesTarget.hidden = isRepl
  }
}
