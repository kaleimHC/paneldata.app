# keyed by iso3c CHAR(3), entity_type distinguishes country/aggregate/subnational/historical.
class Country < ApplicationRecord
  self.primary_key = "iso3c"

  ENTITY_TYPES = %w[country aggregate subnational historical].freeze

  has_many :observations, foreign_key: "country_iso3c", inverse_of: :country
  has_many :country_group_members, foreign_key: "country_iso3c", inverse_of: :country
  has_many :country_groups, through: :country_group_members

  validates :iso3c, presence: true, length: { is: 3 }
  validates :name, presence: true
  validates :entity_type, inclusion: { in: ENTITY_TYPES }

  scope :real, -> { where(entity_type: "country") } # entity_type=country only, excludes aggregates/subnational/historical

  # ── Entity-resolution layer ────────────────────────────────────────────────────────────
  # Single source of truth for mapping foreign country-code systems -> our iso3c. Codes are backfilled
  # into typed columns (m49/iso2) + alt_codes JSONB by db/seeds/country_codes_backfill.rb from the
  # cached countrycode crosswalk. Fetchers declare their COUNTRY_SYSTEM and call Country.resolve /
  # Country.code_index instead of carrying inline maps (supersedes faostat M49_TO_ISO3, un_wpp m49
  # fallback, ihme GBD_ALIASES, wipo/sesric crosswalk lookups).
  #
  # Each system -> the column(s) that hold its code(s). Numeric + alpha variants both index.
  CODE_SYSTEMS = {
    iso3: %i[iso3c],
    iso2: %i[iso2],
    m49:  %i[m49],
    fao:  %w[fao],
    imf:  %w[imf],
    cow:  %w[cown cowc],
    gw:   %w[gwn gwc],
    p4:   %w[p4n p4c],
    p5:   %w[p5n p5c],
    ioc:  %w[ioc]
  }.freeze

  # {code(String) => iso3c} for one system. Cheap (~300 rows); build once per fetch and reuse.
  def self.code_index(system)
    return name_index if system == :name # forgiving API: code_index(:name) == name_index (normalized-name -> iso3c)
    fields = CODE_SYSTEMS.fetch(system) { raise ArgumentError, "unknown country code system #{system.inspect}" }
    idx = {}
    all.find_each do |c|
      fields.each do |f|
        raw = f.is_a?(Symbol) ? c.public_send(f) : c.alt_codes[f]
        code = raw.to_s.strip
        next if code.empty?
        idx[code] ||= c.iso3c
      end
    end
    idx
  end

  # Normalized-name -> iso3c, from name + name_local. For name-keyed sources (e.g. IHME) after a thin
  # spelling-alias pass. Diacritics/punctuation-insensitive.
  def self.name_index
    idx = {}
    all.find_each do |c|
      [c.name, c.name_local].compact.each { |n| idx[normalize_name(n)] ||= c.iso3c }
    end
    idx
  end

  def self.normalize_name(str)
    str.to_s.unicode_normalize(:nfkd).gsub(/[^\p{ASCII}]/, "").downcase.gsub(/[^a-z0-9]+/, " ").strip
  end

  # Resolve a single value to iso3c (String) or nil. system: one of CODE_SYSTEMS keys, :name, or
  # :auto (try iso3 -> m49 -> iso2 -> fao -> cow -> gw -> p5 -> name). Per-row fetcher loops should
  # prefer code_index(system) (build the hash once) over calling resolve repeatedly.
  def self.resolve(value, system: :auto)
    v = value.to_s.strip
    return nil if v.empty?
    case system
    when :auto
      return v if exists?(iso3c: v)
      %i[m49 iso2 fao cow gw p5].each do |s|
        hit = code_index(s)[v]
        return hit if hit
      end
      name_index[normalize_name(v)]
    when :name
      name_index[normalize_name(v)]
    else
      code_index(system)[v]
    end
  end
end
