# Typed result: one GMM diagnostic (AR1/AR2/Sargan) for one equation.
class DiagnosticTest < ApplicationRecord
  belongs_to :analysis_run, inverse_of: :diagnostic_tests
end
