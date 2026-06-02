# WAVE 0: named collection of member countries (EU27, BRICS, OECD, ...).
class CountryGroup < ApplicationRecord
  has_many :country_group_members, inverse_of: :country_group, dependent: :destroy
  has_many :countries, through: :country_group_members

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
