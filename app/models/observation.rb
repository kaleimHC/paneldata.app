# + . Surrogate id PK; natural uniqueness on the 5-tuple. value_type is a PG ENUM.
class Observation < ApplicationRecord
  belongs_to :country, foreign_key: "country_iso3c", primary_key: "iso3c", inverse_of: :observations
  belongs_to :indicator, inverse_of: :observations
  belongs_to :data_ingestion, optional: true

  # value_type_enum - AR enum mapped onto the PG enum column (string-backed).
  enum :value_type, {
    raw: "raw", estimate: "estimate", percentile: "percentile",
    index: "index", rank: "rank", categorical_code: "categorical_code"
  }, prefix: true

  # SDMX CL_OBS_STATUS codes ('A' = Normal default).
  OBS_STATUSES = %w[A b d e f i m n p u].freeze

  # Year bound is a wide SANITY range (matches observations_year_check), NOT a business/data range -
  # data range is per-indicator and dynamic. Floor -10000 covers HYDE/OWID population (10000 BCE).
  validates :year, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: -10000, less_than_or_equal_to: 2100 }
  validates :value, presence: true
  validates :source_revision, presence: true
  validates :obs_status, inclusion: { in: OBS_STATUSES }
end
