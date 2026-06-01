# hierarchy via ancestry gem (materialized path on `ancestry` column).
# `license_record` (not :license) avoids shadowing the indicators.license VARCHAR cache.
class Indicator < ApplicationRecord
  has_ancestry # (gem "ancestry" "~> 5.1")

  belongs_to :data_source, optional: true
  belongs_to :license_record, class_name: "License",
             foreign_key: "license_id", optional: true
  has_many :observations, inverse_of: :indicator

  # Indicators that actually have >=1 observation loaded (env-specific). Keeps the selector from
  # listing catalogued-but-unloaded series (offline/pending sources whose data isn't on this env).
  scope :with_observations, -> { where("EXISTS (SELECT 1 FROM observations o WHERE o.indicator_id = indicators.id)") }

  TRANSFORMS = %w[log levels none].freeze
  FREQUENCIES = %w[annual quarterly monthly].freeze

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :source, presence: true
  validates :transform_default, inclusion: { in: TRANSFORMS }, allow_nil: true
  validates :frequency, inclusion: { in: FREQUENCIES }

  # Localized display name: from config/locales/data/indicators.<locale>.yml keyed by code
  # (dots → underscores; I18n treats dots as key separators), falling back to the English DB `name`.
  # Count-agnostic: adding a language = add indicators.<locale>.yml, no code change.
  def display_name
    I18n.t("data.indicators.#{code.tr('.', '_')}.name", default: name)
  end

  # Loggable = strictly positive over its whole series, so the PVAR predictor's log (lib/r/pvar.R) is defined.
  # Driven by the backfilled value_min cache. value_min nil (no data) -> not loggable (can't prove positivity).
  def loggable?
    value_min.present? && value_min.positive?
  end

  # Computable = eligible for the PVAR / all-pairs estimator: loggable AND the licence permits derivatives.
  # NoDerivatives licences (license_record.modifiable == false, e.g. ECB) are MAP-ONLY: served and displayed
  # verbatim (reproduction is allowed) but EXCLUDED from the estimator, because PVAR is a derivative work.
  # nil licence / nil modifiable -> not blocked here (loggable is then the binding constraint).
  def computable?
    loggable? && license_record&.modifiable != false
  end

  # Backfill the value_min/value_max caches from observations. One grouped pass over ~6.5M rows (~700ms);
  # only writes rows whose cached range drifted, so it is cheap to re-run after an ingest. Used by the backfill
  # migration and by `rake indicators:backfill_value_range`.
  def self.backfill_value_range!
    connection.execute(<<~SQL.squish)
      UPDATE indicators i
         SET value_min = s.mn, value_max = s.mx
        FROM (SELECT indicator_id, MIN(value) AS mn, MAX(value) AS mx
                FROM observations GROUP BY indicator_id) s
       WHERE s.indicator_id = i.id
         AND (i.value_min IS DISTINCT FROM s.mn OR i.value_max IS DISTINCT FROM s.mx)
    SQL
  end
end
