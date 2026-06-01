# append-only vintage. One "latest" per source enforced by partial unique index.
class SourceRevision < ApplicationRecord
  belongs_to :data_source, inverse_of: :source_revisions
  has_many :data_ingestions, inverse_of: :source_revision

  validates :source, presence: true
  validates :revision_code, presence: true, uniqueness: { scope: :source }
  validates :released_at, presence: true
end
