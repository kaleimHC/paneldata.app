# WAVE 0: join row with composite PK (country_group_id, country_iso3c).
class CountryGroupMember < ApplicationRecord
  self.primary_key = %i[country_group_id country_iso3c]

  belongs_to :country_group, inverse_of: :country_group_members
  belongs_to :country, foreign_key: "country_iso3c", primary_key: "iso3c",
             inverse_of: :country_group_members
end
