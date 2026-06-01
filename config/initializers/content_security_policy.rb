# Content Security Policy. Shipped REPORT-ONLY first (harden 2026-06-25, audit: CSP not emitted) - the app
# loads ES modules from https://esm.sh (maplibre-gl, chroma-js, fuse.js), MapLibre spawns blob: workers, and
# the theme bootstrap is an inline <script>. Report-only emits the violation report without breaking the map;
# promote to enforcing (drop report_only) only after validating the console on a real deploy (map + PDF.js +
# esm.sh + theme), which is a conscious prod step.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.base_uri        :self
    policy.frame_ancestors :self
    policy.object_src      :none
    policy.img_src         :self, :https, :data
    policy.font_src        :self, :https, :data
    policy.style_src       :self, :https, :unsafe_inline               # Tailwind utilities + inline theme CSS vars
    policy.script_src      :self, :https, "https://esm.sh"             # importmap + esm.sh modules (+ nonce below)
    policy.connect_src     :self, :https, "https://esm.sh"             # /geo, /api/observations, module fetch
    policy.worker_src      :self, :blob                                # MapLibre GL spawns blob: workers
    policy.child_src       :self, :blob
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Nonce for inline/importmap scripts (styles stay unsafe-inline so Tailwind + theme CSS vars are not broken).
  config.content_security_policy_nonce_generator  = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_nonce_auto       = true

  # REPORT-ONLY until validated on a real deploy. Flip to false (enforcing) as a conscious prod step.
  config.content_security_policy_report_only = true
end
