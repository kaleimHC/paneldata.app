class PagesController < ApplicationController
  # A run selected from the history navigates here as /?run=<id> (a real Turbo visit, like Methodology) so the
  # result renders server-side and the page cross-fades smoothly instead of an in-place JS swap that jumped.
  # Only a completed run flips the page into result-mode; anything else falls back to config-mode.
  def main
    return if params[:run].blank?
    run = AnalysisRun.includes(:predictor_indicator, :response_indicator, :gamma_coefficients,
                               :irf_estimates, :diagnostic_tests).find_by(id: params[:run])
    @run = run if run&.status == "completed"
  end

  # System status (was the inline Rack proof-page; now an ERB view through the layout).
  # System status. This page is PUBLIC, so infra-revealing fields (full PostgreSQL version string, the
  # database name, the hostname, the Ruby platform) are intentionally NOT exposed - only family/version
  # facts that aid nobody. (harden 2026-06-25, audit info-disclosure)
  def system_info
    @rails_version = Rails.version
    @ruby_version = RUBY_VERSION
    @adapter = ActiveRecord::Base.connection.adapter_name   # "PostgreSQL" family only - no version/host/db
    @observation_count = Observation.count
    @env = Rails.env
    @deployed_at = Time.current.utc.iso8601
  end

  def upload; end

  # Working-paper reading view (Methodology): full PDF.js viewer for our replication, copyright-safe
  # first-page teaser + links for Goes (2016). Renders with its own reading-mode topbar, not the app chrome.
  def methodology; end
end
