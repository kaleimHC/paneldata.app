# Typed result: one entry of the 2x2 autoregression matrix Gamma (4 per run).
class GammaCoefficient < ApplicationRecord
  belongs_to :analysis_run, inverse_of: :gamma_coefficients
end
