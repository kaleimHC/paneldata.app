# compute layer: one row per user "Run PVAR" click. State machine = manual enum + CHECK
# (mirrors DataIngestion, no aasm). Estimator plm::pgmm onestep FD. The bootstrap_distributions
# JSONB is cold (read once on result display) - the 2s polling endpoint MUST use .select to stay off it.
class AnalysisRun < ApplicationRecord
  STATUSES = %w[pending running completed failed].freeze
  RESPONSE_CODE = "NY.GDP.PCAP.KD".freeze   # default response (GDP per capita), overridable per run
  BOOTSTRAP = [0, 100, 1000].freeze         # allowed n_bootstrap values

  belongs_to :model_spec, inverse_of: :analysis_runs
  belongs_to :response_indicator,  class_name: "Indicator"
  belongs_to :predictor_indicator, class_name: "Indicator"

  has_many :gamma_coefficients, inverse_of: :analysis_run, dependent: :delete_all
  has_many :irf_estimates,      inverse_of: :analysis_run, dependent: :delete_all
  has_many :diagnostic_tests,   inverse_of: :analysis_run, dependent: :delete_all

  validates :status, inclusion: { in: STATUSES }
  # Defence-in-depth: even a direct Model.create! (bypassing AnalysesController) must stay inside the
  # sanctioned "button" envelope - mirrors the controller guards + the analysis_runs CHECK constraints. (harden 2026-06-25)
  validate :params_within_sanctioned_envelope

  scope :recent, -> { order(created_at: :desc) }

  def terminal? = %w[completed failed].include?(status)

  # gamma_21 (response -> predictor): the L.log_gdp term in the log_efw equation. PVAR variable names are
  # fixed by the estimator (lib/r/pvar.R), so this pair is constant across runs. Read by analyses#show and
  # the result view.
  def gamma_21
    gamma_coefficients.find_by(equation: "log_efw", regressor: "L.log_gdp")
  end

  private

  # Reject anything outside what the pre-programmed UI can submit: bootstrap must be a whitelisted value,
  # and the year window must sit within the data envelope (1..2100, start < end).
  def params_within_sanctioned_envelope
    p = params || {}
    if p["n_bootstrap"].present? && !BOOTSTRAP.include?(p["n_bootstrap"].to_i)
      errors.add(:params, "n_bootstrap must be one of #{BOOTSTRAP.inspect}")
    end
    sy = p["start_year"]; ey = p["end_year"]
    if sy.present? && ey.present? && !(sy.to_i >= 1 && ey.to_i <= 2100 && ey.to_i > sy.to_i)
      errors.add(:params, "year range must satisfy 1 <= start_year < end_year <= 2100")
    end
  end
end
