# Server-rendered PVAR result: the headline + IRF chart + diagnostics for a completed run.
# Ported from the old client-side pvar#render so that navigating into a run from the history is a real Turbo
# visit (smooth view-transition cross-fade, like Methodology) instead of an in-place JS swap that jumped. The
# SVG chart colors are CSS vars via style="" so it re-tints on a theme swap with NO JS (replaces pvar#reTheme).
class AnalysisResultComponent < ViewComponent::Base
  def initialize(run:)
    @run = run
  end

  private

  attr_reader :run

  def predictor = run.predictor_indicator.display_name
  def response  = run.response_indicator.display_name

  def period
    sy = run.params["start_year"]
    ey = run.params["end_year"]
    (sy && ey) ? "#{sy}-#{ey} · " : ""
  end

  # gamma_21 (response -> predictor); mirrors analyses#show exactly (see AnalysisRun#gamma_21).
  def gamma21 = @gamma21 ||= run.gamma_21

  def irf  = @irf  ||= run.irf_estimates.order(:horizon).to_a
  def diag = @diag ||= run.diagnostic_tests.order(:equation, :test_name).to_a

  def f(value, dp = 3)
    value.nil? ? "-" : format("%.#{dp}f", value)
  end

  # i18n with {key} interpolation (same convention as the pvar controller's lbl).
  def pv(key, **vars)
    s = I18n.t("pvar.#{key}")
    vars.each { |k, val| s = s.gsub("{#{k}}", val.to_s) }
    s
  end

  def stat(label, value, sub)
    tag.div(class: "rounded-lg bg-raised px-3 py-2") do
      safe_join([
        tag.div(label, class: "text-[11px] uppercase tracking-wide text-ink-muted"),
        tag.div(value, class: "font-serif text-lg font-semibold text-navy"),
        tag.div(sub, class: "text-[11px] text-ink-soft")
      ])
    end
  end

  # Inline SVG IRF: line + 90% CI band + zero baseline. Colors are CSS custom properties via style="" so the
  # chart follows the active theme live (no getComputedStyle / no re-render on theme:changed).
  def chart_svg
    return "".html_safe if irf.empty?
    w = 460; h = 180; pad = 28
    hs = irf.map(&:horizon)
    vals = irf.flat_map { |p| [p.irf, p.ci_lower, p.ci_upper] }.compact.map(&:to_f)
    lo = ([0.0] + vals).min
    hi = ([0.0] + vals).max
    hi = lo + 1 if hi == lo
    span = [1, (hs.last - hs.first)].max
    x = ->(hor) { (pad + (w - 2 * pad) * (hor - hs.first).to_f / span).round(1) }
    y = ->(v)   { (h - pad - (h - 2 * pad) * (v.to_f - lo) / (hi - lo)).round(1) }
    line = irf.map { |p| "#{x.(p.horizon)},#{y.(p.irf)}" }.join(" ")
    has_ci = irf.all? { |p| !p.ci_lower.nil? && !p.ci_upper.nil? }
    band = ""
    if has_ci
      up = irf.map { |p| "#{x.(p.horizon)},#{y.(p.ci_upper)}" }
      dn = irf.reverse.map { |p| "#{x.(p.horizon)},#{y.(p.ci_lower)}" }
      band = %(<polygon points="#{(up + dn).join(' ')}" style="fill: var(--chart-s1)" opacity="0.14"></polygon>)
    end
    zero_y = y.(0)
    <<~SVG.html_safe
      <svg viewBox="0 0 #{w} #{h}" class="w-full" role="img" aria-label="Impulse response of the response to a predictor shock">
        <line x1="#{pad}" y1="#{zero_y}" x2="#{w - pad}" y2="#{zero_y}" style="stroke: var(--border-color)" stroke-dasharray="3 3"></line>
        #{band}
        <polyline points="#{line}" style="fill: none; stroke: var(--chart-s1)" stroke-width="2"></polyline>
        <text x="#{pad}" y="#{h - 6}" class="text-[10px]" style="fill: var(--text-muted)">year 0</text>
        <text x="#{w - pad - 28}" y="#{h - 6}" class="text-[10px]" style="fill: var(--text-muted)">year #{hs.last}</text>
      </svg>
    SVG
  end
end
