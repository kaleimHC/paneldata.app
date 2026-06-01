# WAVE 0: organization-level source (WB, UNDP, V-Dem, ...). One source -> many vintages.
class DataSource < ApplicationRecord
  # Assoc named :origin_country (not :country_origin) so it does not shadow the
  # country_origin CHAR(3) FK column accessor (same pattern as Indicator#license_record).
  belongs_to :origin_country, class_name: "Country",
             foreign_key: "country_origin", primary_key: "iso3c", optional: true
  has_many :source_revisions, inverse_of: :data_source
  has_many :indicators, inverse_of: :data_source

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
