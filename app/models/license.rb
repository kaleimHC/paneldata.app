# WAVE 0: normalized license registry. indicators link via license_id (assoc named
# :license_record to avoid shadowing the indicators.license VARCHAR cache).
class License < ApplicationRecord
  has_many :indicators, foreign_key: "license_id", inverse_of: :license_record

  validates :name, presence: true
  validates :spdx_code, uniqueness: true, allow_nil: true
end
