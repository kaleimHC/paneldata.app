# provenance / audit trail per fetch operation. Observations link back via data_ingestion_id.
class DataIngestion < ApplicationRecord
  STATUSES = %w[running success failed partial].freeze

  belongs_to :source_revision, inverse_of: :data_ingestions
  has_many :observations, inverse_of: :data_ingestion

  validates :status, inclusion: { in: STATUSES }
end
