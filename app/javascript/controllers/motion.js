// Motion helper: read a CSS motion token (--dur-*) as milliseconds so JS timers/cushions derive from the
// SAME duration ladder as the CSS transitions and can never drift into magic numbers. Not a Stimulus controller
// (no _controller suffix -> eagerLoadControllersFrom skips it); just an importable module under controllers/.
export function durMs(token, fallback = 0) {
  const v = getComputedStyle(document.documentElement).getPropertyValue(token).trim()
  if (!v) return fallback
  if (v.endsWith("ms")) return parseFloat(v)
  if (v.endsWith("s")) return parseFloat(v) * 1000
  const n = parseFloat(v)
  return isNaN(n) ? fallback : n
}
