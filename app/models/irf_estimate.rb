# Typed result: impulse-response of GDP to a predictor shock at one horizon (11 per run, h=0..10).
class IrfEstimate < ApplicationRecord
  belongs_to :analysis_run, inverse_of: :irf_estimates
end
