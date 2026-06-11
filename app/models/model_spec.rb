# Registry of econometric model definitions. Each analysis_run references one (PVAR_Goes_2016 this MVP).
class ModelSpec < ApplicationRecord
  has_many :analysis_runs, inverse_of: :model_spec, dependent: :restrict_with_exception
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
